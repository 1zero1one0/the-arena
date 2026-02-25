terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

resource "random_password" "tunnel_secret" {
  length  = 64
  special = false
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "main" {
  account_id = var.cloudflare_account_id
  name       = "${var.project}-${var.environment}-tunnel"
  secret     = base64sha256(random_password.tunnel_secret.result)
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "main" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.main.id

  config {
    ingress_rule {
      hostname = var.admin_hostname
      service  = "https://${var.admin_app_fqdn}"

      origin_request {
        no_tls_verify    = true
        http_host_header = var.admin_app_fqdn
      }
    }

    ingress_rule {
      service = "http_status:404"
    }
  }
}

# DNS record managed manually in Cloudflare dashboard
# CNAME: admin -> 1ae171d6-a19d-44c6-90f6-f2d4fa36c0e0.cfargotunnel.com (proxied)
