azure = {
  location            = "uksouth"
  resource_group_name = "rg-portfolio-hosting"
}

environment = {
  name = "portfolio-hosting"
}

application = {
  name         = "portfolio"
  hostname     = "portfolio.dev.michaelalinks.com"
  min_replicas = 1
}

dns_zone = {
  name                = "dev.michaelalinks.com"
  resource_group_name = "kubernetes"
}

registry = {
  name                = "localacrk8s"
  resource_group_name = "kubernetes"
}

cluster = {
  resource_group_name = "rg-management"
  name                = "aks-management"
}

preview_cleanup = {
  schedule     = "0 2 * * *"
  github_owner = "ai-platform-portfolio"
}
