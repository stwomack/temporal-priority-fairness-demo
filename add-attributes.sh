temporal --namespace default operator search-attribute create --name Priority --type int --command-timeout 60s --client-connect-timeout 60s
temporal --namespace default operator search-attribute create --name ActivitiesCompleted --type int --command-timeout 60s --client-connect-timeout 60s
temporal --namespace default operator search-attribute create --name FairnessKey --type keyword --command-timeout 60s --client-connect-timeout 60s
temporal --namespace default operator search-attribute create --name FairnessWeight --type int --command-timeout 60s --client-connect-timeout 60s
