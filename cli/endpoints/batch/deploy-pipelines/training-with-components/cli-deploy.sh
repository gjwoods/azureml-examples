#<connect_workspace>
az account set --subscription <subscription>
az configure --defaults workspace=<workspace> group=<resource-group> location=<location> 
#</connect_workspace>

#<create_random_endpoint_name>
ENDPOINT_SUFIX=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${1:-5} | head -n 1)
ENDPOINT_NAME="uci-classifier-train-$ENDPOINT_SUFIX"
#</create_random_endpoint_name>

#<environment_registration>
az ml environment create -f environment/xgboost-sklearn-py38.yml
#</environment_registration>

#<data_asset_registration>
az ml data create --name heart-classifier-train --type uri_folder --path data/train
#</data_asset_registration>

#<test_pipeline>
az ml job create -f deployment-ordinal/pipeline-job.yml --set inputs.input_data.path=azureml:heart-classifier-train@latest
#</test_pipeline>

#<create_endpoint>
az ml batch-endpoint create --name $ENDPOINT_NAME -f endpoint.yml
#</create_endpoint>

#<create_deployment>
az ml batch-deployment create --endpoint $ENDPOINT_NAME -f deployment-ordinal/deployment.yml --set-default
#</create_deployment>

#<invoke_deployment_file>
JOB_NAME=$(az ml batch-endpoint invoke -n $ENDPOINT_NAME --f inputs.yml | jq -r ".name")
#</invoke_deployment_file>

#<stream_job_logs>
az ml job stream -n $JOB_NAME
#</stream_job_logs>

#<child_jobs_name_prepare>
PREPARE_JOB=$(az ml job list --parent-job-name $JOB_NAME | jq -r ".[0].name")
#</child_jobs_name_prepare>

#<download_outputs_prepare>
az ml job download --name $PREPARE_JOB --output-name transformations
#/download_outputs_prepare>

#<child_jobs_name_train>
TRAIN_JOB=$(az ml job list --parent-job-name $JOB_NAME | jq -r ".[1].name")
#</child_jobs_name_train>

#<download_outputs_train>
az ml job download --name $TRAIN_JOB --output-name model
az ml job download --name $TRAIN_JOB --output-name evaluation_results
#/download_outputs_train>

#<create_nondefault_deployment>
az ml batch-deployment create --endpoint $ENDPOINT_NAME -f deployment-onehot/deployment.yml
#</create_nondefault_deployment>

#<invoke_nondefault_deployment_file>
DEPLOYMENT_NAME="uci-classifier-train-onehot"
JOB_NAME=$(az ml batch-endpoint invoke -n $ENDPOINT_NAME -d $DEPLOYMENT_NAME --f inputs.yml | jq -r ".name")
#</invoke_nondefault_deployment_file>

#<stream_nondefault_job_logs>
az ml job stream -n $JOB_NAME
#</stream_nondefault_job_logs>

#<delete_endpoint>
az ml batch-endpoint delete -n $ENDPOINT_NAME --yes
#</delete_endpoint>