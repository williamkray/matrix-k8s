this is the base synapse installation with postgres database.

use kustomize to generate configMaps and secrets associated with the installation. configurations can be modified by
updating the config files and secret files stored in ./configs and ./secrets respectively.

to deploy multiple instances of synapse, copy these directories and the ./kustomization.yaml file to a subdirectory,
make any necessary changes to the files for this specific deployment (particularly the namePrefix field) and use
kustomize to manage and deploy the stacks.

these default configs have placeholder secrets, DO NOT USE THESE. be sure to use secure passwords and do not commit
these files to the repository.
