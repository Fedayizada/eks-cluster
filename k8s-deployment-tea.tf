
resource "kubernetes_deployment" "tea" {
  depends_on = [ module.eks_cluster]
  metadata {
    annotations  = {
     "backstage.io/kubernetes-id" = "kubernetes-component" 
      }
    name = "tea"
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "tea"
      }
    }

    template {
      metadata {
        labels = {
          app = "tea"
        }
      }

      spec {
        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key = "kubernetes.io/arch"
                  operator = "In"
                  values = [ "x86_64" ,"amd64"]
                }
              }
            }
          }
        }
        container {
          image = "nginxdemos/nginx-hello:plain-text"
          name  = "tea"
          port {
            container_port = 8080
          }

          resources {
            limits =  {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests  = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }

        }
      }
    }
  }
}

resource "kubernetes_service" "tea" {
  metadata {
    name = "tea"
  }
  spec {
    selector = {
      app = kubernetes_deployment.tea.spec.0.selector.0.match_labels.app
    }
    port {
      port        = 80
      target_port = 8080
      name        = "http"
      protocol    = "TCP"
    }

    type = "NodePort"
  }
}

resource "kubernetes_ingress_v1" "tea" {
  metadata {
    name = "tea"
    annotations = {
      "kubernetes.io/ingress.class" = "alb"
      #"external-dns.alpha.kubernetes.io/alias" = "true"
      "alb.ingress.kubernetes.io/scheme" = "internal"
      "alb.ingress.kubernetes.io/target-type" =  "instance"
      "alb.ingress.kubernetes.io/group.name" = "cafe"
      "alb.ingress.kubernetes.io/certificate-arn" = "arn:aws:acm:us-east-1:004889159502:certificate/b68381cc-f4c0-4aa3-b686-a719a02ee873"
      "alb.ingress.kubernetes.io/actions.ssl-redirect" = jsonencode({"Type" =  "redirect", "RedirectConfig" =  { "Protocol" =  "HTTPS", "Port" =  "443", "StatusCode" =  "HTTP_301"}})
      "alb.ingress.kubernetes.io/listen-ports" =  jsonencode([{"HTTPS" = 443},{"HTTP" = 80}] )

    }
  }

  spec {
    
    rule {
      host = "test.techsdemo.com"
      http {
        path {
          backend {
            service {
              name = kubernetes_service.tea.metadata.0.name
            
            port {
              number = 80
          }
          }
          }

          path = "/tea"
        }

      }
    }
  }
}