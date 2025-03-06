Based on the code you've provided and the configurations I've generated (Jenkinsfile, Dockerfile, deployment.yml, and updated pom.xml), here’s a detailed guide on what you need to do with **AWS** and **Jenkins** to get your Java Web Application running and producing the desired output ("Welcome to your demo project!" page). I'll focus on the specific actions required on AWS and Jenkins to achieve this.

---

### Objective
Deploy your Java Web Application (a simple servlet redirecting to a welcome JSP page) to an AWS EKS cluster using Jenkins for CI/CD.

---

### Things to Do on AWS

#### 1. Set Up ECR (Elastic Container Registry)
- **Purpose**: Store your Docker image.
- **Steps**:
  1. Log in to the AWS Management Console or use the AWS CLI.
  2. Create an ECR repository:
     ```bash
     aws ecr create-repository --repository-name demo-project --region us-east-1
     ```
  3. Note the repository URI (e.g., `<your-account-id>.dkr.ecr.us-east-1.amazonaws.com/demo-project`).
  4. Update your `Jenkinsfile` and `deployment.yml` with this URI:
     - In `Jenkinsfile`: Replace `<your-account-id>` in `ECR_REGISTRY`.
     - In `deployment.yml`: Replace the `image` field under `containers`.

#### 2. Set Up EKS (Elastic Kubernetes Service)
- **Purpose**: Host your Kubernetes cluster for deployment.
- **Steps**:
  1. Install `eksctl` if not already installed:
     ```bash
     curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
     sudo mv /tmp/eksctl /usr/local/bin
     ```
  2. Create an EKS cluster:
     ```bash
     eksctl create cluster \
       --name demo-cluster \
       --region us-east-1 \
       --nodegroup-name standard-workers \
       --node-type t3.medium \
       --nodes 2 \
       --nodes-min 1 \
       --nodes-max 3 \
       --managed
     ```
     - This takes ~15-20 minutes.
  3. Verify the cluster:
     ```bash
     kubectl get nodes
     ```
  4. Update kubeconfig:
     ```bash
     aws eks update-kubeconfig --region us-east-1 --name demo-cluster
     ```

#### 3. Configure IAM Permissions
- **Purpose**: Allow Jenkins and EKS to interact with AWS services.
- **Steps**:
  1. Create an IAM user for Jenkins:
     - Go to IAM > Users > Add User
     - Name: `jenkins-user`
     - Access type: Programmatic access
     - Attach policies:
       - `AmazonEC2ContainerRegistryFullAccess`
       - `AmazonEKSClusterPolicy`
       - `AmazonEKSWorkerNodePolicy`
     - Save the Access Key ID and Secret Access Key.
  2. Ensure the EKS cluster role has these policies (automatically added by `eksctl`):
     - `AmazonEKSClusterPolicy`
     - `AmazonEKSWorkerNodePolicy`
     - `AmazonEC2ContainerRegistryReadOnly`

#### 4. Security Group Configuration
- **Purpose**: Allow traffic to your application.
- **Steps**:
  1. In the AWS Console, go to VPC > Security Groups.
  2. Find the security group associated with your EKS worker nodes (named something like `eksctl-demo-cluster-nodegroup-standard-workers`).
  3. Add an inbound rule:
     - Type: HTTP
     - Protocol: TCP
     - Port: 80
     - Source: 0.0.0.0/0 (or restrict to your IP for testing)

---

### Things to Do on Jenkins

#### 1. Set Up Jenkins Server
- **Purpose**: Automate the build, push, and deploy process.
- **Steps** (if not already running):
  1. Launch an EC2 instance (e.g., Amazon Linux 2, t2.medium).
  2. Install Jenkins:
     ```bash
     sudo yum update -y
     sudo amazon-linux-extras install java-openjdk11 -y
     sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
     sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
     sudo yum install jenkins -y
     sudo systemctl start jenkins
     sudo systemctl enable jenkins
     ```
  3. Access Jenkins at `http://<ec2-public-ip>:8080` and unlock it using the initial admin password (found in `/var/lib/jenkins/secrets/initialAdminPassword`).

#### 2. Install Plugins
- **Purpose**: Enable Docker, Kubernetes, and AWS integration.
- **Steps**:
  1. Go to Manage Jenkins > Manage Plugins > Available.
  2. Install:
     - Docker
     - Docker Pipeline
     - AWS Steps
     - Kubernetes
     - Maven Integration
     - Git
  3. Restart Jenkins if prompted.

#### 3. Configure Tools
- **Purpose**: Ensure Jenkins can build and deploy your app.
- **Steps**:
  1. Manage Jenkins > Global Tool Configuration:
     - **Maven**: Add "Maven 3" (auto-install).
     - **JDK**: Add "JDK 11" (auto-install).
     - **Docker**: Add Docker installation (auto-install).

#### 4. Add Credentials
- **Purpose**: Allow Jenkins to access AWS and GitHub.
- **Steps**:
  1. Manage Jenkins > Manage Credentials > System > Global credentials:
     - **AWS Credentials**:
       - Kind: AWS Credentials
       - ID: `aws-credentials`
       - Access Key ID: `<from IAM user>`
       - Secret Access Key: `<from IAM user>`
     - **GitHub Credentials** (if repo is private):
       - Kind: Username with password
       - ID: `github-credentials`
       - Username: `<your-github-username>`
       - Password: `<your-github-token-or-password>`

#### 5. Create and Configure Pipeline
- **Purpose**: Define the CI/CD process.
- **Steps**:
  1. New Item > Pipeline > Name: "Demo-Project-Pipeline".
  2. Configuration:
     - Check "GitHub project" and add `https://github.com/your-username/demo-project`.
     - Pipeline > Definition: Pipeline script from SCM.
     - SCM: Git.
     - Repository URL: `https://github.com/your-username/demo-project.git`.
     - Credentials: Select `github-credentials` (or leave blank for public repo).
     - Branch: `main`.
     - Script Path: `Jenkinsfile`.
  3. Save the pipeline.

#### 6. Trigger the Build
- **Purpose**: Execute the CI/CD pipeline.
- **Steps**:
  1. Click "Build Now" on the pipeline page.
  2. Monitor the console output for:
     - Maven build success
     - Docker image build and push to ECR
     - Kubernetes deployment

---

### Verify the Output
1. **Check Deployment**:
   - After the pipeline completes:
     ```bash
     kubectl get pods
     ```
     - Ensure pods are in "Running" status.

2. **Get Service URL**:
   - Run:
     ```bash
     kubectl get svc demo-service
     ```
   - Look for the `EXTERNAL-IP` (it might take a few minutes to appear).

3. **Access the Application**:
   - Open a browser and go to `http://<external-ip>`.
   - Expected Output:
     - Initial redirect from `index.jsp`
     - Final page showing: `<h1>Welcome to your demo project!</h1>`

---

### Troubleshooting
- **AWS Issues**:
  - ECR Push Fails: Run `aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <your-account-id>.dkr.ecr.us-east-1.amazonaws.com` manually to test.
  - EKS Not Responding: Verify `kubectl get nodes` works and security groups allow traffic.
- **Jenkins Issues**:
  - Build Fails: Check console for Maven/Docker errors (e.g., missing dependencies or permissions).
  - Pipeline Stuck: Ensure AWS credentials are correct and Jenkins has Docker/Kubectl installed.
- **Application Issues**:
  - Blank Page: Verify Tomcat logs with `kubectl logs <pod-name>`.

---

### Final Checklist
- [ ] ECR repository created and URI updated in files.
- [ ] EKS cluster running and accessible.
- [ ] Jenkins installed with plugins and credentials.
- [ ] Pipeline executed successfully.
- [ ] External IP accessible and showing the welcome page.

Once these steps are completed, your Java Web Application will be live on AWS EKS, and you'll see the "Welcome to your demo project!" output. Let me know if you hit any snags!
