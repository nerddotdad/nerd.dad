---
comments: true
generate_audio: true
date:
    created: 2025-04-03
draft: false
categories:
    - projects
tags:
    - ai
---
# AI Gamer Project - Part 4 - Tuning github interactions

Thanks for the spam!

<!-- more -->
So I left off last night with a dockerfile that build a docker image that was pulled by a kubernetes cluster.

That pod would run it's install, run the model, then create a github issue.

This is super cool! except now I have 15 issues in the 30 minutes it ran. So I'm working to allocate a single issue to the bot's interactions.

The latest version of the `train.py` script looks like this

```python
import os
import gymnasium as gym
from stable_baselines3 import PPO
import requests
import re

# GitHub repo details
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
REPO_OWNER = "nerddotdad"
REPO_NAME = "ai-gamer"
config = {
    "env_name": "CartPole-v1",
    "total_timesteps": 10_000,
    "checkpoint_name": "ppo_cartpole",
    "episode_count": 10,
    "avg_reward": 165.2,
    "max_reward": 200,
    "training_time": "12m 43s",
    "avg_length": 189,
    "loss": 0.132,
    "exploration_rate": 0.05,
    "behavior_notes": "Stable balance achieved after 3 episodes. Occasional early failure around step 90.",
    "next_steps": "Increase training to 20 episodes and test reward penalty for jerky movement."
}

def create_github_issue(title, body):
    url = f"https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/issues"
    headers = {"Authorization": f"token {GITHUB_TOKEN}", "Accept": "application/vnd.github.v3+json"}
    data = {"title": title, "body": body}
    response = requests.post(url, json=data, headers=headers)
    return response.status_code, response.json()

def fetch_latest_issue_comments():
    # Fetch the latest issue in the repo
    url = f"https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/issues?state=open"
    headers = {"Authorization": f"token {GITHUB_TOKEN}", "Accept": "application/vnd.github.v3+json"}
    response = requests.get(url, headers=headers)
    issues = response.json()

    if issues:
        issue_number = issues[0]['number']
        comments_url = f"https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/issues/{issue_number}/comments"
        comments_response = requests.get(comments_url, headers=headers)
        return comments_response.json()
    return []

def parse_tweaks_from_comments(comments):
    tweaks = {}
    for comment in comments:
        match = re.search(r"\[tweaks\](.*?)\[/tweaks\]", comment['body'], re.DOTALL)
        if match:
            tweak_content = match.group(1)
            for line in tweak_content.splitlines():
                if "=" in line:
                    key, value = line.split("=", 1)
                    tweaks[key.strip()] = value.strip()
    return tweaks

def apply_tweaks_to_config(tweaks, config):
    for key, value in tweaks.items():
        if key in config:
            try:
                config[key] = eval(value)  # This safely evaluates basic Python expressions (like numbers, strings, etc.)
            except Exception as e:
                print(f"Failed to apply tweak for {key}: {e}")
    return config

def format_github_issue(config):
    return f"""
## 🎮 AI Training Session Summary

**Environment:** {config["env_name"]}
**Total Episodes:** {config["episode_count"]}
**Avg. Reward:** {config["avg_reward"]}
**Max Reward:** {config["max_reward"]}
**Training Time:** {config["training_time"]}

---

## 📈 Training Stats
- Avg. Episode Length: {config["avg_length"]} steps
- Loss (last 10 episodes): {config["loss"]}
- Exploration Rate: {config["exploration_rate"]}
- Model Checkpoint: `{config["checkpoint_name"]}`

---

## 🧠 Behavior Observations
{config["behavior_notes"]}

---

## 🚀 Next Steps
{config["next_steps"]}

---

## 🛠️ User Tweaks
Comment below with any changes you’d like to see for the next run. Example:

[tweaks] episodes = 50 learning_rate = 0.0005 notes = Try using a different gym environment: "MountainCar-v0" [/tweaks]
"""

# Fetch the latest issue comments and apply any tweaks
comments = fetch_latest_issue_comments()
tweaks = parse_tweaks_from_comments(comments)
config = apply_tweaks_to_config(tweaks, config)

# Select an environment
env = gym.make(config["env_name"])
model = PPO("MlpPolicy", env, verbose=1)

# Train the model
model.learn(total_timesteps=config["total_timesteps"])

# Save the model
model.save(config["checkpoint_name"])

# Notify via GitHub Issues
issue_title = f"Training Complete: {config['env_name']}"

issue_body = format_github_issue(config)

status, response = create_github_issue(issue_title, issue_body)

if status == 201:
    print(f"Issue created: {response.get('html_url')}")
else:
    print("Failed to create issue.")
    print("GitHub API response:", response)
```

Right now I'm working on making this script run in a loop so I don't have to worry about the pod spinning up after each run. I also am setting up a PVC mount to persist the model data between runs if the pod does restart.

```yaml ai-model-deployment.yaml
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
          imagePullPolicy: Always
          env:
            - name: INSTALL_PACKAGES
              value: "true"
            - name: GITHUB_TOKEN
              valueFrom:
                secretKeyRef:
                  name: github-secret
                  key: GITHUB_TOKEN
          volumeMounts:
            - name: model-volume
              mountPath: /data
      volumes:
        - name: model-volume
          persistentVolumeClaim:
            claimName: model-pvc
```