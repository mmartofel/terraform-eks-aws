# terraform-eks-aws

To specify your custom cluster name, you can run:

```terraform apply -var="cluster_name=your_custom_name"```

otherwise it will default to `zenek`


git clone https://github.com/hashicorp-education/learn-terraform-provision-eks-cluster

eksctl option:

eksctl create cluster -f eks-cluster-1.32.yaml

connect to cluster:

aws eks update-kubeconfig --region us-east-1 --name development

kubectl get svc

NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.100.0.1   <none>        443/TCP   13m

EKS documentation:
https://docs.aws.amazon.com/eks/latest/userguide/quickstart.html

Hashicorp documentation:
https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks