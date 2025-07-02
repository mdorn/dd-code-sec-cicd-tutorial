TASK_ARN=$(aws ecs list-tasks --service-name "${PREFIX}-service" --query 'taskArns[0]' --output text --cluster ${PREFIX}-cluster)
TASK_DETAILS=$(aws ecs describe-tasks --task "${TASK_ARN}" --query 'tasks[0].attachments[0].details' --cluster ${PREFIX}-cluster)
ENI=$(echo $TASK_DETAILS | jq -r '.[] | select(.name=="networkInterfaceId").value')
IP=$(aws ec2 describe-network-interfaces --network-interface-ids "${ENI}" --query 'NetworkInterfaces[0].Association.PublicIp' --output text)
echo $IP
# echo "IP is ${IP}"
# curl "http://${IP}:8000"
