---
comments: true
generate_audio: true
date:
    created: 2025-04-03
draft: false
categories:
    - Projects
tags:
    - ai
---
# AI Gamer Project - Part 3 - The AI Model

So far so good... is this where things get complicated?

<!-- more -->

So now that my kubernetes cluster is stood up and looking good my AI assistant asked what I'd like to do next. I chose to set up the AI model.

It gave the recommendation to use `Stable-Baselines3` as it supports algorithms like PPO and DQN. We'll go with that for now since we're learning :smile:

## Installing More Dependencies

```shell title="Install Dependencies"
sudo apt update && sudo apt install python3-pip python3-venv
```

```shell title="Create a python virtual environment and install the library"
python3 -m venv ai-model-env
source ai-model-env/bin/activate
pip install stable-baselines3[extra] gymnasium numpy torch
```

!!! warning title "pip install error"

    I hit an issue with the above pip install cause I'm on zsh... If you hit an issue there you may need to run this instead

    ```shell
    pip install 'stable-baselines3[extra]'
    ```


```shell title="Create and move into a working dir"
mkdir ~/ai-model && cd ~/ai-model
```

## There be dragons... LLMs are powerful but you still need braincells

Now I started getting some actual code. This is where, in my experience, things can get a bit harry with ai... Let's see how it goes.

### Python

It has me create the below python script. I wanted my ai to communicate with me through github issues. Let's see how that works out...

```python title="train.py"
import os
import gymnasium as gym
from stable_baselines3 import PPO
import requests

# GitHub repo details
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
REPO_OWNER = "your-username"
REPO_NAME = "ai-gamer"

def create_github_issue(title, body):
    url = f"https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/issues"
    headers = {"Authorization": f"token {GITHUB_TOKEN}", "Accept": "application/vnd.github.v3+json"}
    data = {"title": title, "body": body}
    response = requests.post(url, json=data, headers=headers)
    return response.status_code, response.json()

# Select an environment
env = gym.make("CartPole-v1")
model = PPO("MlpPolicy", env, verbose=1)

# Train the model
model.learn(total_timesteps=10_000)

# Save the model
model.save("ppo_cartpole")

# Notify via GitHub Issues
issue_title = "Training Complete: CartPole-v1"
issue_body = "The AI has completed training on CartPole-v1 with 10,000 timesteps."
status, response = create_github_issue(issue_title, issue_body)

print(f"Issue created: {response.get('html_url')}" if status == 201 else "Failed to create issue.")
```

It had me create a github repo [nerddotdad/ai-gamer](https://github.com/nerddotdad/ai-gamer) and create a personal access token for that repo. Then put it into a kubernetes secret.

```shell
kubectl create secret generic github-secret --from-literal=GITHUB_TOKEN='your-github-token'
```

### Docker

It then has be create a docker file to package the model. 

??? failure title "Mistakes were made, learn from them here!"

    ??? failure title "Failure 1: This makes a 9GB docker file..."

        The first docker file attempt resulted in a massive file and I don't want to pay for repo space. This lead me to the next option.

        ```dockerfile
        # Stage 1: Build stage
        FROM python:3.10 AS builder

        # Install necessary dependencies for building the application
        WORKDIR /app

        # Copy the train.py file
        COPY train.py /app/

        # Install required Python libraries (including gym and RL dependencies)
        RUN pip install --no-cache-dir stable-baselines3[extra] gymnasium torch numpy

        # Stage 2: Final image
        FROM python:3.10-slim

        # Set working directory
        WORKDIR /app

        # Copy the application from the builder stage (without build dependencies)
        COPY --from=builder /app /app

        # Only keep necessary files (optional)
        # RUN rm -rf /app/tests /app/*.pyc /app/*.pyo

        # Run the training script
        CMD ["python", "train.py"]
        ```

    ??? failure title "Failure 2: Smaller but broken!"

        This dockerfile created a docker image that was well under the size budget... But later down the road I found out that it was missing a few dependencies that was blocking my pod from starting up.

        ```dockerfile
        # Use a minimal base image, like Python Alpine
        FROM python:3.10-alpine

        # Set working directory
        WORKDIR /app

        # Copy the application code
        COPY train.py /app/

        # Install minimal dependencies like pip
        RUN apk add --no-cache gcc musl-dev libffi-dev

        # Copy the entrypoint script to install dependencies at runtime
        COPY entrypoint.sh /app/entrypoint.sh

        # Make the script executable
        RUN chmod +x /app/entrypoint.sh

        # Set entrypoint to the install script
        ENTRYPOINT ["/app/entrypoint.sh"]

        # Default command when running the container
        CMD ["python", "train.py"]
        ```

    ??? failure title "Failure 3: Lacked the dependancies I needed!"

        This dockerfile resulted in build errors but we were getting closer!

        ```dockerfile
        # Use a minimal base image, like Python Alpine
        FROM python:3.10-alpine

        # Set working directory
        WORKDIR /app

        # Install minimal system dependencies (for basic operations)
        RUN apk add --no-cache gcc musl-dev libffi-dev bash

        # Copy the application code
        COPY train.py /app/

        # Copy the entrypoint script to install dependencies at runtime
        COPY entrypoint.sh /app/entrypoint.sh

        # Make the script executable
        RUN chmod +x /app/entrypoint.sh

        # Set entrypoint to the install script
        ENTRYPOINT ["/app/entrypoint.sh"]

        # Default command when running the container
        CMD ["python", "train.py"]
        ```

!!! note title "Happy Path"

    ```dockerfile
    # Use a Debian-based Python image (slim) for better compatibility
    FROM python:3.11-slim

    # Set working directory
    WORKDIR /app

    # Copy the application code
    COPY train.py /app/

    # Install system dependencies needed for compiling packages like torch
    RUN apt-get update && \
        apt-get install -y gcc libffi-dev musl-dev && \
        apt-get clean

    # Copy the entrypoint script to install dependencies at runtime
    COPY entrypoint.sh /app/entrypoint.sh

    # Make the script executable
    RUN chmod +x /app/entrypoint.sh

    # Set entrypoint to the install script
    ENTRYPOINT ["/app/entrypoint.sh"]

    # Default command when running the container
    CMD ["python", "train.py"]
    ```

    This path required I make a script to go into my docker container in order to execute the installation of the dependencies.

    ```shell
    #!/bin/sh

    # Install dependencies if the INSTALL_PACKAGES flag is set
    if [ "$INSTALL_PACKAGES" = "true" ]; then
    echo "Installing Python dependencies..."
    pip install --upgrade pip
    pip install torch stable-baselines3 gymnasium requests
    fi

    # Run the main application
    exec "$@"
    ```

Huzzah! A much smaller docker file at the expense of a longer build time during deploy. Something I'm totally fine with cause I don't anticipate deploying this a lot.

Now I'll login, build, and push the docker image
```shell
docker login
docker build -t nerddotdad/ai-model:latest .
docker push nerddotdad/ai-model:latest
```

Since I ran into a few failures with the dockerfile I tested before deploying to my kubernetes cluster. You can see that when I run the docker file I can see the entrypoint script and it's executable... There's hope!

```shell
docker run -it nerddotdad/ai-model:latest /bin/bash
bba5a4a977f1:/app# ls
entrypoint.sh  train.py
```

### Kubernetes

After that hurdle I'm back on track to deploy to kubernetes. I'll start by creating a yaml kubernetes config file

??? failure title "Mistakes were made, learn from them here!"

    ??? failure title "Failure 1"

        ```yaml title="ai-model-deployment.yaml"
        apiVersion: apps/v1
        kind: Deployment
        metadata:
        name: ai-model-deployment
        labels:
            app: ai-model
        spec:
        replicas: 1
        selector:
            matchLabels:
            app: ai-model
        template:
            metadata:
            labels:
                app: ai-model
            spec:
            containers:
                - name: ai-model
                image: nerddotdadai-model:latest  # Replace with your Docker image
                imagePullPolicy: Always
                ports:
                    - containerPort: 80  # Replace with the correct port for your app
                resources:
                    limits:
                    memory: "2Gi"  # Adjust the resources as needed
                    cpu: "1"  # Adjust the CPU limits as needed
                env:
                    - name: INSTALL_PACKAGES
                    value: "true"  # Trigger installation logic in entrypoint script
                    - name: GITHUB_TOKEN  # GitHub token for interacting with GitHub Issues
                    valueFrom:
                        secretKeyRef:
                        name: github-api  # The name of the secret
                        key: GITHUB_TOKEN  # The key name within the secret
                volumeMounts:
                    - name: model-volume
                    mountPath: /app
            volumes:
                - name: model-volume
                emptyDir: {}
        ---
        apiVersion: v1
        kind: Service
        metadata:
        name: ai-model-service
        spec:
        selector:
            app: ai-model
        ports:
            - protocol: TCP
            port: 80
            targetPort: 80  # Adjust if needed
        type: ClusterIP
        ```

        Well that didn't turn out did it. Let's see what went wrong.

        ```shell
        NAME                                  READY   STATUS                       RESTARTS   AGE
        ai-model-deployment-df88df567-vsxk5   0/1     CreateContainerConfigError   0          7s
        ```

        I described the pod and see that there was an error with the secret not being found.

        ```shell 
        Warning  Failed     10s (x5 over 54s)  kubelet            Error: secret "github-api" not found
        ```

        Let me go back and ensure I have the right secret name

        ```shell
        kubectl get secrets
        NAME            TYPE     DATA   AGE
        github-secret   Opaque   1      41m
        ```

        womp womp. It was wrong. (it gets worse! check failure 2)

    ??? failure title "Failure 2"

        ```yaml title="ai-model-deployment.yaml"
        apiVersion: apps/v1
        kind: Deployment
        metadata:
        name: ai-model-deployment
        labels:
            app: ai-model
        spec:
        replicas: 1
        selector:
            matchLabels:
            app: ai-model
        template:
            metadata:
            labels:
                app: ai-model
            spec:
            containers:
                - name: ai-model
                image: nerddotdadai-model:latest  # Replace with your Docker image
                imagePullPolicy: Always
                ports:
                    - containerPort: 80  # Replace with the correct port for your app
                resources:
                    limits:
                    memory: "2Gi"  # Adjust the resources as needed
                    cpu: "1"  # Adjust the CPU limits as needed
                env:
                    - name: INSTALL_PACKAGES
                    value: "true"  # Trigger installation logic in entrypoint script
                    - name: GITHUB_TOKEN  # GitHub token for interacting with GitHub Issues
                    valueFrom:
                        secretKeyRef:
                        name: github-secret  # The name of the secret
                        key: GITHUB_TOKEN  # The key name within the secret
                volumeMounts:
                    - name: model-volume
                    mountPath: /app
            volumes:
                - name: model-volume
                emptyDir: {}
        ---
        apiVersion: v1
        kind: Service
        metadata:
        name: ai-model-service
        spec:
        selector:
            app: ai-model
        ports:
            - protocol: TCP
            port: 80
            targetPort: 80  # Adjust if needed
        type: ClusterIP
        ```

        extra womp womp... another failure... This time it had to do with the `volumeMounts` portion of the `ai-model-deployment.yaml` overriding the /app dir which was blowing away the `entrypoint.sh` script.

        and yes... it get's worse before it get's better

    ??? failure title "Failure 2"

        ```yaml
        apiVersion: apps/v1
        kind: Deployment
        metadata:
        name: ai-model-deployment
        spec:
        replicas: 1
        selector:
            matchLabels:
            app: ai-model
        template:
            metadata:
            labels:
                app: ai-model
            spec:
            containers:
                - name: ai-model
                image: nerddotdad/ai-model:latest
                imagePullPolicy: Always  # Ensure the latest image is pulled
                env:
                    - name: INSTALL_PACKAGES
                    value: "true"
                    - name: GITHUB_TOKEN
                    valueFrom:
                        secretKeyRef:
                        name: github-secret
                        key: GITHUB_TOKEN
                volumeMounts:
                    # Removed the mount for /app as it was overwriting the directory
                    - name: model-volume
                    mountPath: /data  # You can use a different path for the volume if needed
            volumes:
                # Removed EmptyDir from /app to ensure the files inside the Docker image aren't overwritten
                - name: model-volume
                emptyDir: {}  # This is now a separate volume for other purposes, e.g., data storage
        ```

        Turns out we had some pip install issues during the build. I was really excited cause I saw my pod was `RUNNING`. I went to update my blog post and then BAM `STATUS: CrashLoopBackOff` :sob:

!!! note title "Happy Path"

    Finally we got a docker image that was working and a deployment that was successful in kubernetes!

    ```yaml title="ai-model-deployment.yaml"
    apiVersion: apps/v1
    kind: Deployment
    metadata:
    name: ai-model-deployment
    spec:
    replicas: 1
    selector:
        matchLabels:
        app: ai-model
    template:
        metadata:
        labels:
            app: ai-model
        spec:
        containers:
            - name: ai-model
            image: nerddotdad/ai-model:latest
            imagePullPolicy: Always  # Ensure the latest image is pulled
            env:
                - name: INSTALL_PACKAGES
                value: "true"
                - name: GITHUB_TOKEN
                valueFrom:
                    secretKeyRef:
                    name: github-secret
                    key: GITHUB_TOKEN
            volumeMounts:
                # Removed the mount for /app as it was overwriting the directory
                - name: model-volume
                mountPath: /data  # You can use a different path for the volume if needed
        volumes:
            # Removed EmptyDir from /app to ensure the files inside the Docker image aren't overwritten
            - name: model-volume
            emptyDir: {}  # This is now a separate volume for other purposes, e.g., data storage
    ```

We got output like this.

```shell
---------------------------------
| rollout/           |          |
|    ep_len_mean     | 24.8     |
|    ep_rew_mean     | 24.8     |
| time/              |          |
|    fps             | 2804     |
|    iterations      | 1        |
|    time_elapsed    | 0        |
|    total_timesteps | 2048     |
---------------------------------
```

and this...

```shell
| rollout/                |              |
|    ep_len_mean          | 59.1         |
|    ep_rew_mean          | 59.1         |
| time/                   |              |
|    fps                  | 673          |
|    iterations           | 5            |
|    time_elapsed         | 15           |
|    total_timesteps      | 10240        |
| train/                  |              |
|    approx_kl            | 0.0072752135 |
|    clip_fraction        | 0.0688       |
|    clip_range           | 0.2          |
|    entropy_loss         | -0.606       |
|    explained_variance   | 0.267        |
|    learning_rate        | 0.0003       |
|    loss                 | 29.9         |
|    n_updates            | 40           |
|    policy_gradient_loss | -0.018       |
|    value_loss           | 60           |
------------------------------------------
```

and then...

!!! failure title "this..."

    ```shell
    Failed to create issue.
    ```

UGH! It's 11:30 at night. Everyone is asleep. I feel Like I'm so close to getting this going. Let's see what we have to do.

My AI buddy recommended I exec into the pod and try to slam the github api with a curl to see what happens. Funny, I don't remember having curl install into the pod... I didn't... That's ok, instead I exec into the pod and echo my GITHUB_TOKEN env var if that exists then we know it's something else...

Well turns out that in the `train.py` script I needed to put my github username... FIXED! let's see what happens!

- docker image rebuild :white_check_mark:
- docker image pushed :white_check_mark:
- kubernetes deployment deleted :white_check_mark:
- kubernetes deployment applied :white_check_mark:

```shell
kubectl logs -f ai-model-deployment-6f9ff49ccb-fr868
Installing Python dependencies...

...
random install junk
...

Wrapping the env with a `Monitor` wrapper
Wrapping the env in a DummyVecEnv.
---------------------------------
| rollout/           |          |
|    ep_len_mean     | 22.6     |
|    ep_rew_mean     | 22.6     |
| time/              |          |
|    fps             | 3250     |
|    iterations      | 1        |
|    time_elapsed    | 0        |
|    total_timesteps | 2048     |
---------------------------------
-----------------------------------------
| rollout/                |             |
|    ep_len_mean          | 28.6        |
|    ep_rew_mean          | 28.6        |
| time/                   |             |
|    fps                  | 960         |
|    iterations           | 2           |
|    time_elapsed         | 4           |
|    total_timesteps      | 4096        |
| train/                  |             |
|    approx_kl            | 0.008351874 |
|    clip_fraction        | 0.109       |
|    clip_range           | 0.2         |
|    entropy_loss         | -0.686      |
|    explained_variance   | -0.00344    |
|    learning_rate        | 0.0003      |
|    loss                 | 8.91        |
|    n_updates            | 10          |
|    policy_gradient_loss | -0.0181     |
|    value_loss           | 54.5        |
-----------------------------------------
-----------------------------------------
| rollout/                |             |
|    ep_len_mean          | 35.2        |
|    ep_rew_mean          | 35.2        |
| time/                   |             |
|    fps                  | 758         |
|    iterations           | 3           |
|    time_elapsed         | 8           |
|    total_timesteps      | 6144        |
| train/                  |             |
|    approx_kl            | 0.010126373 |
|    clip_fraction        | 0.0796      |
|    clip_range           | 0.2         |
|    entropy_loss         | -0.662      |
|    explained_variance   | 0.0961      |
|    learning_rate        | 0.0003      |
|    loss                 | 14.7        |
|    n_updates            | 20          |
|    policy_gradient_loss | -0.0219     |
|    value_loss           | 37.8        |
-----------------------------------------
-----------------------------------------
| rollout/                |             |
|    ep_len_mean          | 48.5        |
|    ep_rew_mean          | 48.5        |
| time/                   |             |
|    fps                  | 678         |
|    iterations           | 4           |
|    time_elapsed         | 12          |
|    total_timesteps      | 8192        |
| train/                  |             |
|    approx_kl            | 0.008221371 |
|    clip_fraction        | 0.0815      |
|    clip_range           | 0.2         |
|    entropy_loss         | -0.631      |
|    explained_variance   | 0.239       |
|    learning_rate        | 0.0003      |
|    loss                 | 18.7        |
|    n_updates            | 30          |
|    policy_gradient_loss | -0.0205     |
|    value_loss           | 50.1        |
-----------------------------------------
------------------------------------------
| rollout/                |              |
|    ep_len_mean          | 62.4         |
|    ep_rew_mean          | 62.4         |
| time/                   |              |
|    fps                  | 662          |
|    iterations           | 5            |
|    time_elapsed         | 15           |
|    total_timesteps      | 10240        |
| train/                  |              |
|    approx_kl            | 0.0063599707 |
|    clip_fraction        | 0.044        |
|    clip_range           | 0.2          |
|    entropy_loss         | -0.609       |
|    explained_variance   | 0.261        |
|    learning_rate        | 0.0003       |
|    loss                 | 30.5         |
|    n_updates            | 40           |
|    policy_gradient_loss | -0.013       |
|    value_loss           | 61.5         |
------------------------------------------
Issue created: https://github.com/nerddotdad/ai-gamer/issues/1
```

Let's goooo!!!

The automation made it's first issue!

[Github Issue #1](https://github.com/nerddotdad/ai-gamer/issues/1)

## Conclusion

This is an excellent stopping point for the night. I'm going to call it here. Hopefully you learned something along the way like I did! Leave a comment here on my blog if you liked it!

## Share
