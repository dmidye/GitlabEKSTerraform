data "aws_iam_policy_document" "assume_role" {
  count = local.enabled ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "default" {
  count              = local.enabled ? 1 : 0
  name               = module.label.id
  assume_role_policy = join("", data.aws_iam_policy_document.assume_role.*.json)
  tags               = module.label.tags
}

resource "aws_iam_role_policy_attachment" "amazon_eks_cluster_policy" {
  count      = local.enabled ? 1 : 0
  policy_arn = format("arn:%s:iam::aws:policy/AmazonEKSClusterPolicy", join("", data.aws_partition.current.*.partition))
  role       = join("", aws_iam_role.default.*.name)
}

resource "aws_iam_role_policy_attachment" "amazon_eks_service_policy" {
  count      = local.enabled ? 1 : 0
  policy_arn = format("arn:%s:iam::aws:policy/AmazonEKSServicePolicy", join("", data.aws_partition.current.*.partition))
  role       = join("", aws_iam_role.default.*.name)
}

# AmazonEKSClusterPolicy managed policy doesn't contain all necessary permissions to create
# ELB service-linked role required during LB provisioning by Kubernetes.
# Because of that, on a new AWS account (where load balancers have not been provisioned yet, `nginx-ingress` fails to provision a load balancer

data "aws_iam_policy_document" "cluster_elb_service_role" {
  count = local.enabled ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeInternetGateways",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSubnets"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "cluster_elb_service_role" {
  count  = local.enabled ? 1 : 0
  name   = module.label.id
  role   = join("", aws_iam_role.default.*.name)
  policy = join("", data.aws_iam_policy_document.cluster_elb_service_role.*.json)
}

# Node group role
resource "aws_iam_role" "gitlab-cluster-role" {
  name = "gitlab-node-group-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

# Leaving these in just in case --> see the node group resource 'depends_on' clause in main.tf

# resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSWorkerNodePolicy" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
#   role       = aws_iam_role.gitlab-cluster-role.name
# }

# resource "aws_iam_role_policy_attachment" "cluster-AmazonEKS_CNI_Policy" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
#   role       = aws_iam_role.gitlab-cluster-role.name
# }

# resource "aws_iam_role_policy_attachment" "cluster-AmazonEC2ContainerRegistryReadOnly" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
#   role       = aws_iam_role.gitlab-cluster-role.name
# }
