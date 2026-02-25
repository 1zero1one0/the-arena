# the-arena

Best practice platform for Azure in US-Central-1

What we need:

Platform:
    - App Service
    - SQL Database
    - SignalR
    - Virtual Machines
    - Storage accounts
    - Container Registry
    - Function App
    - Container Apps
        - All resources internal
        - Public facing applications via Cloudflare tunnel
        - Connection to MongoDB on Atlas
        - All resources internal only public facing via cloudflare
    - Do not deploy those services yet
    - Best practice templates for App Services, SQL Database, SignalR, Virtual Machines, Storage accounts, container registry, function app, container apps. Just templates to deploy into the best practice environment.
    - Template applications should follow GIT commit rules to production or staging. Credentials stored in github to deploy to container registrys. Fully automated.
    - Folders with template applications and possibly function to create new application based on template into new repository
    - Credentials stored in keyvault
  
Frontend:
    - Cloudflare
    - Azure Tunnel
    - Zero Trust access to azure internal vnet
    - Zero trust access for empolyees and developers

Please make some solid recomendations, then start building. The base infrastructure should be deployed via script possibly terraform and the template applications should also follow the terraform guildines. Helper tasks for the various stages of adding applications to the new environment.

We are starting from scratch with a new resource group and everything should be in there. The production services should have DR container scaled to 0 to reduce cost.

