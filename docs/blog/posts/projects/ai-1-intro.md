---
comments: true
generate_audio: true
date:
    created: 2025-04-01
draft: false
categories:
    - projects
tags:
    - ai
---
# AI Gamer Project - Part 1 - Introduction

So I decided that I'm going to take a dive into AI...

<!-- more -->

I dabbled in it with the audio generation project for these blogs but I feel like that was a minimal use. So I'm using AI to help me learn AI. I'll be tackling this project in phases and will be documenting live!

## Phase 1: Infrastructure Setup

Kubernetes on WSL – Set up a local Kubernetes cluster on your Windows machine using WSL. Minikube or K3s would be good lightweight options.

Deploy Grafana & Prometheus – Set up a monitoring stack within the cluster to collect and visualize metrics.

## Phase 2: Game & AI Integration

Choose a Game – Select a game with a suitable interface for AI control. Something with a simple API or OpenAI Gym support would be ideal.

Agentic AI Model – Start with a reinforcement learning (RL) model (e.g., PPO or DQN) using frameworks like Stable-Baselines3 or RLlib.

Capture Gameplay & Model Actions – Use OBS Studio (or a custom GStreamer setup) to stream the game and AI model decisions.

## Phase 3: Website & Dashboard

Live Streaming – Set up a video feed on your website (e.g., via RTMP to a web player).

Metrics Dashboard – Expose model training insights and actions on Grafana, embedded below the stream.

Would you like to start with setting up the Kubernetes cluster or the AI model?

## Conclusion

Wish me luck!!! This is going to be one hell of an adventure!