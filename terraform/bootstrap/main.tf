# Bootstrap: recursos que deben existir ANTES de la infraestructura principal.
#  - Bucket S3 para el estado remoto de Terraform
#  - Repositorio ECR para las imágenes de PassFly
#  - Proveedor OIDC + roles IAM para que GitHub Actions acceda a AWS sin claves
# Se ejecuta UNA vez, a mano, con tus credenciales de AWS (estado local).

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  repo_full  = "${var.github_owner}/${var.github_repo}"
}

# ---------- Estado remoto ----------
resource "aws_s3_bucket" "tfstate" {
  bucket = "passfly-tfstate-${local.account_id}-${var.aws_region}"
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------- Registro de imágenes ----------
resource "aws_ecr_repository" "passfly" {
  name                 = "passfly"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "passfly" {
  repository = aws_ecr_repository.passfly.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Conservar solo las últimas 10 imágenes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

# ---------- GitHub Actions (OIDC) ----------
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  # GitHub puede emitir el "sub" con o sin los IDs numéricos de propietario y repo:
  #   repo:OWNER/REPO:...            (clásico)
  #   repo:OWNER@123/REPO@456:...    (con IDs inmutables)
  sub_prefixes = [
    "repo:${local.repo_full}",
    "repo:${var.github_owner}@*/${var.github_repo}@*",
  ]

  oidc_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

data "aws_iam_policy_document" "trust_ci" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # CI solo publica imágenes desde la rama main
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for p in local.sub_prefixes : "${p}:ref:refs/heads/main"]
    }
  }
}

data "aws_iam_policy_document" "trust_cd" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # CD solo desde el environment protegido
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for p in local.sub_prefixes : "${p}:environment:${var.github_environment}"]
    }
  }
}

# --- Rol CI: solo empuja imágenes a ECR ---
resource "aws_iam_role" "ci" {
  name               = "passfly-github-ci"
  assume_role_policy = data.aws_iam_policy_document.trust_ci.json
}

data "aws_iam_policy_document" "ci" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:DescribeImages",
    ]
    resources = [aws_ecr_repository.passfly.arn]
  }
}

resource "aws_iam_role_policy" "ci" {
  name   = "ecr-push"
  role   = aws_iam_role.ci.id
  policy = data.aws_iam_policy_document.ci.json
}

# --- Rol CD: ejecuta terraform apply sobre la infraestructura de PassFly ---
resource "aws_iam_role" "cd" {
  name               = "passfly-github-cd"
  assume_role_policy = data.aws_iam_policy_document.trust_cd.json
}

data "aws_iam_policy_document" "cd" {
  statement {
    sid       = "Compute"
    actions   = ["ec2:*"]
    resources = ["*"]
  }

  statement {
    sid = "IamSoloPassfly"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:PassRole",
      "iam:TagRole", "iam:UntagRole", "iam:ListRoleTags", "iam:ListInstanceProfileTags", "iam:UpdateAssumeRolePolicy",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy",
      "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy",
      "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole",
      "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile", "iam:GetInstanceProfile",
      "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile", "iam:UntagInstanceProfile",
    ]
    resources = [
      "arn:aws:iam::${local.account_id}:role/passfly-app-*",
      "arn:aws:iam::${local.account_id}:instance-profile/passfly-app-*",
    ]
  }

  statement {
    sid       = "AmiPublicaUbuntu"
    actions   = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:${var.aws_region}::parameter/aws/service/canonical/*"]
  }

  statement {
    sid       = "LecturaEcr"
    actions   = ["ecr:DescribeRepositories", "ecr:DescribeImages", "ecr:ListTagsForResource"]
    resources = [aws_ecr_repository.passfly.arn]
  }

  statement {
    sid       = "EstadoListar"
    actions   = ["s3:ListBucket", "s3:GetBucketVersioning"]
    resources = [aws_s3_bucket.tfstate.arn]
  }

  statement {
    sid       = "EstadoObjetos"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.tfstate.arn}/*"]
  }
}

resource "aws_iam_role_policy" "cd" {
  name   = "terraform-passfly"
  role   = aws_iam_role.cd.id
  policy = data.aws_iam_policy_document.cd.json
}

# --- Rol PLAN: solo lectura, para `terraform plan` en pull requests ---
data "aws_iam_policy_document" "trust_plan" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for p in local.sub_prefixes : "${p}:pull_request"]
    }
  }
}

resource "aws_iam_role" "plan" {
  name               = "passfly-github-plan"
  assume_role_policy = data.aws_iam_policy_document.trust_plan.json
}

data "aws_iam_policy_document" "plan" {
  statement {
    sid = "LecturaInfra"
    actions = [
      "ec2:Describe*",
      "ecr:Describe*",
      "ecr:ListTagsForResource",
      "ecr:GetRepositoryPolicy",
      "ecr:GetLifecyclePolicy",
      "ssm:GetParameter",
    ]
    resources = ["*"]
  }

  statement {
    sid     = "LecturaIamPassfly"
    actions = ["iam:Get*", "iam:List*"]
    resources = [
      "arn:aws:iam::${local.account_id}:role/passfly-app-*",
      "arn:aws:iam::${local.account_id}:instance-profile/passfly-app-*",
    ]
  }

  statement {
    sid       = "LecturaEstado"
    actions   = ["s3:ListBucket", "s3:GetBucketVersioning"]
    resources = [aws_s3_bucket.tfstate.arn]
  }

  statement {
    sid       = "LecturaEstadoObjetos"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.tfstate.arn}/*"]
  }
}

resource "aws_iam_role_policy" "plan" {
  name   = "terraform-plan-readonly"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan.json
}
