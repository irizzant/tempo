{
  bitnami: {
    sealedSecret:: {
      metadata: {
        withName(name): { metadata+: { name: name } },
        withNamespace(namespace): { metadata+: { namespace: namespace } },
      },
      new(name): {
        apiVersion: 'bitnami.com/v1alpha1',
        kind: 'SealedSecret',
      } + self.metadata.withName(name=name),
      spec: {
        encryptedData: {
          withEncryptedData(data): { spec+: { encryptedData: data } },
          withEncryptedDataMixin(data): { spec+: { encryptedData+: data } },
        },
      },
    },
  },
}
