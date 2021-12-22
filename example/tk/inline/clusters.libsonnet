[
  {
    local minio = import 'minio/minio.libsonnet',
    local k = import 'ksonnet-util/kausal.libsonnet',
    local container = k.core.v1.container,
    local secret = k.core.v1.secret,
    local containerPort = k.core.v1.containerPort,
    local rule = k.networking.v1.ingressRule,
    local path = k.networking.v1.httpIngressPath,
    local envVar = k.core.v1.envVar,
    local sealedSecrets = import 'sealedsecrets.libsonnet',
    local sealedSecret = sealedSecrets.bitnami.sealedSecret,
    local tempo = import '../tempo-microservices/main.jsonnet',

    data: tempo,

    name: 'k3d-test',
    apiServer: 'https://0.0.0.0:35987',
    namespace: 'grafana-test',

    dataOverride: {
      _images+:: {
        // images can be overridden here if desired
      },

      _config+:: {

        search_enabled: true,
        
        variables_expansion: true,
		variables_expansion_env_mixin: [
          envVar.withName('S3_ACCESS_KEY')
          + envVar.valueFrom.secretKeyRef.withKey('S3_ACCESS_KEY')
          + envVar.valueFrom.secretKeyRef.withName('minio-secret'),
          envVar.withName('S3_SECRET_KEY')
          + envVar.valueFrom.secretKeyRef.withKey('S3_SECRET_KEY')
          + envVar.valueFrom.secretKeyRef.withName('minio-secret'),
        ],

        overrides+:: {
          '*': {
            max_traces_per_user: 100000,
            ingestion_rate_limit_bytes: 200e5,  // ~20MB per sec
            ingestion_burst_size_bytes: 200e5,  // ~20MB
            max_bytes_per_trace: 300e5,  // ~30MB
          },
        },
        distributor+: {
          receivers: {
            jaeger: {
              protocols: {
                thrift_http: null,
                grpc: null,
              },
            },
            otlp: {
              protocols: {
                grpc: {
                  max_recv_msg_size_mib: 134,
                },
                http: null,
              },
            },
          },
        },

      },  // end _config

      tempo_distributor_container+::
        container.withPortsMixin([
          containerPort.new('jaeger-grpc', 14250),
          containerPort.new('otel-grpc', 4317),
          containerPort.new('otel-http', 55681),
        ]),

      tempo_querier_config+:: {
        server+: {
          grpc_server_max_recv_msg_size: 1.34217728e+08,
          grpc_server_max_send_msg_size: 1.34217728e+08,
        },
        querier+: {
          frontend_worker+: {
            grpc_client_config+: {
              max_send_msg_size: 1.34217728e+08,
              max_recv_msg_size: 1.34217728e+08,
            },
          },
        },
      },
      tempo_query_frontend_config+:: {
        server+: {
          grpc_server_max_recv_msg_size: 1.34217728e+08,
          grpc_server_max_send_msg_size: 1.34217728e+08,
        },
        querier+: {
          frontend_worker+: {
            grpc_client_config+: {
              max_send_msg_size: 1.34217728e+08,
              max_recv_msg_size: 1.34217728e+08,
            },
          },
        },
      },

      tempo_querier_container+:: {},

      tempo_query_frontend_container+:: {},

      tempo_ingester_container+:: {},

      local ingressRulesArray = std.map(
        function(v) v {
          host: 'grafana-tempo.127.0.0.1.nip.io',
        },
        super.ingress.spec.rules
      ),

      ingress+: {
        spec+: {
          rules: ingressRulesArray,
        },
      },

      tempo_config+:: {
        storage+: {
          trace+: {
            s3+: {
              endpoint: 'minio.minio.svc.cluster.local:9000',
              access_key: '${S3_ACCESS_KEY}',
              secret_key: '${S3_SECRET_KEY}',
              insecure: true,
            },
          },
        },
      },

      tempo_compactor_container+:: {},

      minio_secret: sealedSecret.new('minio-secret') +
                    sealedSecret.spec.encryptedData.withEncryptedData({
                      S3_ACCESS_KEY: 'AgAdCeevLz/LruondA4THAKo3mYT3A83aw9XdRRWgUvwsh6hZ5B+F4ehYDR5hd3UFyb8PGefXWHpjDIbWlgoFdZlFVEnF4GAdIh/m/w1+NKu87S8WGqQsZsQjY2kyvUO85qjdlzv8uNX0pjkpn2+BMyhUJUSnVjc1uX6IQwPRR3D+LuryZ2xpHPalkRpFZocYo8E3TjKmbr0S6U9VAsB5MxyznsRrsISnlZG/Vidr39J+Jtd/XVrc3YrGHarz8rPNTO6dyKr4kkornxyzaE7rm/kzNee6m8s2IiObmA4GU/XDuBswR2rvC5l9I3j8GpaZqXqzr2B5N422cSV6WzGXfpKbxT3CrLJy53vA2Q3x+pfwmZkgbWhPnj/Z5K+ClXmawQqqlkck68jdGQkVmbnKE6y6REervrwY7Hb0T6wRqrdJk5yQUh2AjE6v97tSGxxy2s3/ZyQwhpOioGxDIqfCXFcTbstt0laSwMuRHPq7RrdfpsTGmE8CcZ3Aj4AZLYm8OXk3lsy1CSLBNsw2RrKI7I20qbXXxUfYbNe7yDPYGws85fQ2CBl2kzCRnGW0Z+P5WB1S0MxsDUsrOj7j1wKXmU5K7+6kqI86XFDmbjyzhbM4xpqydTJYlXhBc15llJz9TOwbFr5AVqHKmVoPPtUA8vc0EMiy1kY36cU9qZ/lb2BMBuQULvACo2Yc+7/fxuvXKlgzNzUm6ZTqE/f',
                      S3_SECRET_KEY: 'AgAXvL73dd4VLOcXnJdmkSpOHWR7UojloyDJUVzRQAikM+FggEfapzyDhNDXSSLlKY3JpsXDFhQZ51eJiQA7o6yyMUHGLqR6a4vLbHZh4sFoUWj77aoApxM3JkgA5UtDl0gTQaS3kLraJb6jmVevo0YUJzHtyDhtHLs8Uawimh1pxl9lNLTJEPAykSd6a7O8/MGMVBFZ7amkJTl43PNwKaQkjfr2PMcDvSSpcgPFo75VexnhuM+u90VkWwpqsUrbz7nlgmVMfSMkhm2edtur/IxR2u6g8VWax9L/MOdcNFgS1NTxjVY7lm8wxMeXTRi0NdMa51gahYJxlYgN9/FmsClAYKn+nf0RMt1hQSHKeNl+P4fl2/RcJsQ7yhQ4JQdJBEp1LPfJJwQZJZj5kZ6rvdubiTgxdquAG1WJYJk6Ut1DPC4cvMIs5lc5xS+QBBNGeBGtvqHEzVaR8sSJRENXA2MiKjzVlRph4ND4uvwXXA126+0EoT36MOuyXde68oMiJrx+ljVMqzdEXhsKkKgMmo+hrDORa3yVJpzBMzYar4+Aa700L3fe1nsfbx0nMUBJBi/7jv9Ru81WeUFPdCRkd6HJvBBlgYdaZw8ksF085Z1ldjVMrvWfUpPVnls5prv8tFwscNXx68qaTfd2nOWYbf86/3Udd3dkgXZizyDJAqFwx5yeVDmTHGm+D7Y+GmeDznRdfeSRDBXP4NCVBJ0KvTXj',
                    }),

    } + {  // disabilitazione deploy di minio
      [field]: {}
      for field in std.objectFieldsAll(minio)
    },  // end dataOverride

  },
]
