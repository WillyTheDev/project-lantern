# 🔦 Project Lantern

Social-Extraction Crawler (PvPvE non-shooter) built with Godot 4.

## 🚀 Deployment Workflow

### 1. Build and Push to Harbor
Ensure you are logged into your registry first:
```bash
docker login harbor.kube.dungeonmomo.cc
```

Build and push the multi-role image:
```bash
# Build the image
docker build -t harbor.kube.dungeonmomo.cc/project-lantern/project-lantern:latest .

# Push to registry
docker build -t harbor.kube.dungeonmomo.cc/project-lantern/project-lantern:latest .
docker push harbor.kube.dungeonmomo.cc/project-lantern/project-lantern:latest
```

### 2. Deploy to Kubernetes
Ensure your `kubectl` context is correctly set to your cluster.

```bash
# Create the namespace if it doesn't exist
kubectl create namespace project-lantern --dry-run=client -o yaml | kubectl apply -f -

# Apply the full infrastructure (PocketBase + Hub + Dungeon)
kubectl apply -f k8s/deployment.yaml
```

### 3. Verify Deployment
```bash
# Check pods status
kubectl get pods -n project-lantern

# Get the External IPs for the game servers
kubectl get svc -n project-lantern
```

## 🛠 Local Development

### Running the Hub Server
```bash
godot --headless -- --hub
```

### Running the Dungeon Server
```bash
godot --headless -- --dungeon
```

### Running the Client
```bash
godot
```

## 📂 Architecture
- **Hub:** Port 9797 (UDP) - Social persistent space.
- **Dungeon:** Port 9798 (UDP) - Extraction gameplay shard.
- **Combat:** Server-authoritative sword-based combat.
- **Vitality:** Stats-scaled health and death-to-hub loop.
- **Looting:** Physical loot drops with drag-and-drop UI.
- **Database:** PocketBase (Internal) - Handles player and inventory persistence.
- **Transitions:** Secure token-based handoff (See [Shard Transitions](docs/SHARD_TRANSITIONS.md)).

## 📖 Documentation
- **[Shard Transitions & Token Handoff](docs/SHARD_TRANSITIONS.md)**: Detailed explanation of multi-server authentication.
- **[Technical Debt Tracking](docs/TECH_DEBT.md)**: Known shortcuts and security vulnerabilities to address.
- **[Project Roadmap](docs/ROADMAP.md)**: Detailed plan for future features and iterations.
- **[GCD (Game Design Document)](GCD.md)**: Original design and game pillars.
- **[Iteration 2 Review](docs/ITERATION_2_REVIEW.md)**: Summary of the Hub & Social Loop implementation.
