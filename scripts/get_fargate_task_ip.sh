export SERVICE_NAME="dd-sec-demo-service"

TASK_ARN=$(aws ecs list-tasks --service-name "$SERVICE_NAME" --query 'taskArns[0]' --output text --cluster dd-sec-demo-cluster)
TASK_DETAILS=$(aws ecs describe-tasks --task "${TASK_ARN}" --query 'tasks[0].attachments[0].details' --cluster dd-sec-demo-cluster)
ENI=$(echo $TASK_DETAILS | jq -r '.[] | select(.name=="networkInterfaceId").value')
IP=$(aws ec2 describe-network-interfaces --network-interface-ids "${ENI}" --query 'NetworkInterfaces[0].Association.PublicIp' --output text)
echo $IP
# echo "IP is ${IP}"
# curl "http://${IP}:8000"
