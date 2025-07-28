#!/bin/bash

# Add variable definitions
PROFILE="hf_eolus"
BUCKET_NAME="hf-eolus-bucket"


UPDATE_CONFIG="true"
ROLE="hf-spectra-processing-vila2-lambda-role"
POLICY="hf-spectra-processing-vila2-lambda-policy"
MEASSPATTERN_S3_PATH="s3://hf-eolus-bucket/hf_processing/APMs/VILA/2015-10-19_131943.txt"
TESTFILE_S3_PATH="s3://hf-eolus-bucket/INTECMAR/VILA/Spectra/CSS/VILA_CSS_2015_W46_Nov/CSS_VILA_15_11_13_1830.cs"
OUTPUT_S3_PATH="s3://hf-eolus-bucket/hf_processing/VILA/VILA2/results"
MANIFEST_S3_PATH="s3://hf-eolus-bucket/hf_processing/VILA/VILA2/manifest/manifest.csv"
LAMBDA_NAME="vila2_process"
ECR_REPO_NAME="hf_process_vila2_lambda"
REGION="eu-west-3"
S3_RESOURCE_ARN="arn:aws:s3:::hf-eolus-bucket/*"
SPECTRA_PREFIX="INTECMAR/VILA/Spectra/CSS/"
REFRESH_ROLE_POLICY_LAMBDA="true"


REFRESH_MANIFEST="true"
START_DATE="2015-10-19 1319"
END_DATE="2015-12-30 2359"

RUN_JOBS="true"
BATH_ROLE="hf-spectra-processing-vila2-batch-lambda-role"
BATH_POLICY="hf-spectra-processing-vila2-batch-lambda-policy"
REPORT_PREFIX="hf_processing/VILA/VILA2/reports"
CONFIRM_JOB="no"


#END_DATE="2015-10-19 131943"

if [ "$UPDATE_CONFIG" = "true" ]; then

    if [ "$REFRESH_ROLE_POLICY_LAMBDA" = "true" ]; then
        # Agregar eliminación del role y de la policy
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile $PROFILE)
        
        # Comprobar si el rol existe antes de eliminarlo
        role_exist=$(aws iam get-role --role-name $ROLE --profile $PROFILE 2>&1)
        if ! echo "$role_exist" | grep -q 'NoSuchEntity'; then
            aws iam detach-role-policy --role-name $ROLE --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/$POLICY --profile $PROFILE
            aws iam delete-role --role-name $ROLE --profile $PROFILE
        fi


        # Comprobar si la política existe antes de eliminarla
        policy_exist=$(aws iam get-policy --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/$POLICY --profile $PROFILE 2>&1)
        if ! echo "$policy_exist" | grep -q 'NoSuchEntity'; then
            aws iam delete-policy --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/$POLICY --profile $PROFILE
        fi

        # Comprobar si la función Lambda existe antes de eliminarla
        lambda_exist=$(aws lambda get-function --function-name $LAMBDA_NAME --profile $PROFILE 2>&1)
        if ! echo "$lambda_exist" | grep -q 'ResourceNotFoundException'; then
            aws lambda delete-function --function-name $LAMBDA_NAME --profile $PROFILE
        fi


    fi

    
    cp ../../SeaSondeRAWSLambdaDocker/Dockerfile ./
    cp ../../SeaSondeRAWSLambdaDocker/configure_seasonder.sh ./
    cp ../../SeaSondeRAWSLambdaDocker/runtime.R ./

    rm response.json
    chmod +x configure_seasonder.sh
    ./configure_seasonder.sh -A $PROFILE \
                            -E $ECR_REPO_NAME \
                            -L $LAMBDA_NAME \
                            -T "${MEASSPATTERN_S3_PATH}" \
                            -R $ROLE \
                            -P $POLICY \
                            -S $OUTPUT_S3_PATH \
                            -K "${TESTFILE_S3_PATH}" \
                            -g $REGION \
                            -u $S3_RESOURCE_ARN 
                            
fi

if [ "$REFRESH_MANIFEST" = "true" ]; then
    # Comprobar si el archivo de manifiesto existe antes de eliminarlo
    manifest_exist=$(aws s3api head-object --bucket $BUCKET_NAME --key $MANIFEST_S3_PATH 2>&1)
    if ! echo "$manifest_exist" | grep -q 'NoSuchKey'; then
        aws s3 rm $MANIFEST_S3_PATH --profile $PROFILE
    fi
    cp ../../SeaSondeRAWSLambdaDocker/prepare_manifest.sh ./

    chmod +x prepare_manifest.sh

    JQ_FILTER="
      .Contents[]
      | select(.Key | test(\"CSS_VILA_\\\\d{2}_\\\\d{2}_\\\\d{2}_\\\\d{4}\\\\.cs4\"))
      | select((.Key | capture(\"CSS_VILA_(?<year>\\\\d{2})_(?<month>\\\\d{2})_(?<day>\\\\d{2})_(?<time>\\\\d{4})\") | \"20\(.year)-\(.month)-\(.day) \(.time)\") as \$file_date
        | \$file_date >= \"$START_DATE\" and \$file_date <= \"$END_DATE\")
      | \"\(\$bucket),\(.Key)\""

    ./prepare_manifest.sh -b $BUCKET_NAME -p "${SPECTRA_PREFIX}" -r $PROFILE -j "$JQ_FILTER" -d $MANIFEST_S3_PATH

fi


if [ "$RUN_JOBS" = "true" ]; then
    cp ../../SeaSondeRAWSLambdaDocker/run_batch_job.sh ./
    chmod +x run_batch_job.sh
    ./run_batch_job.sh -U $MANIFEST_S3_PATH \
                      -g $REGION \
                      -r $BATH_ROLE \
                      -y $BATH_POLICY \
                      -l $LAMBDA_NAME \
                      -p $PROFILE \
                      -c $CONFIRM_JOB \
                      -P $REPORT_PREFIX

fi



