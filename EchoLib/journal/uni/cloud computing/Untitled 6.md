- add a postgres controller k8s
- serviços não deve expor para o exterior
- serviço de autenticação na cloud - users service - not a good idea (keyclock/identity/auth0) - sem ser programado
- implementar os serviços phase 6
- add volume por causa do backup da db
- definir estrategia do rollout no yaml deployments
- alterar o path para ter o nome do serviço  ( nao tem crirerio no ingress) - ver logs de nginx

- readiness probe 
- livelss probe - add
- ressouce limit add

CHECK SELF ASSEMENTS AS A GUIDE

