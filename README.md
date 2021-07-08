this repo is meant as a starting point for learning kubernetes, and to grow that knowledge into a persistent,
continuously updated environment for a full matrix stack including:

- synapse
- postgresql
- element
- matrix-media-repo
- nginx
- traefik
- maubot
- mautrix-signal
- prometheus
- grafana
- matrix-registration

bear with me on this journey.

current incarnation is entirely tested on minikube, so no actual testing on lke/doke.

steps:
modify variables.env as you see fit, or copy it to a new location and modify that. duplicate content to your hearts
content, just be sure to use the same naming format for your variables.

then, run bootstrap-cluster.sh to configure some baseline features of your cluster like nginx-ingress and
prometheus-operator.

if you chose to use unique namespaces in your variables.env file, execute the script:

    ./create-namespaces.sh path/to/variables/file.env

in order to create the prerequisite namespaces. if you do not supply a different variables file, the default will be
used.

next, execute:

    ./generate-overlays.sh path/to/variables/file.env

to generate kustomize overlays based on your variables you've set. you should be able to find them under the app's
`overlays` directory. you are then free to execute `kubectl apply -k apps/<the app>/overlays/<your overlay>` to deploy
it to your kubernetes cluster.

this is pretty untested still, and there are lots of config changes that need to be made as well as even the most basic
features that aren't working yet. currently it deploys synapse with postgres, and matrix-media-repo with postgres.

