# Connect to the cluster
1) aws configure  
2) aws sts get-session-token --serial-number *arn-of-the-mfa-device* --token-code *mfa-code*  
3) aws eks update-kubeconfig --name *name-of-cluster* --profile mfa --region us-gov-west-1  
4) kubectl get nodes  
   - Should return a list of the three worker nodes deployed  

# Deploy and Connect to Kubernetes Dashboard
https://docs.aws.amazon.com/eks/latest/userguide/dashboard-tutorial.html  

If using Powershell, the command for step 4.1 won't work. The following command will write a lot of tokens to a text file named tokens.txt:  

**kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | Select-String -Pattern 'eks-admin' | awk '{print $1}') | Out-File -FilePath ./tokens.txt**

After it finishes, ctrl-f "eks-admin" and copy the token. Use it to authenticate with the Kubernetes Dashbboard.

Visit the link below after running kubectl proxy:  
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#!/login



# Deploy the test application
1) kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.41.2/deploy/static/provider/cloud/deploy.yaml  
2) kubectl apply -f *path-to-k8s-manifests*  
3) kubectl describe svc ingress-nginx-controller -n ingress-nginx  
   - Should see "Ensured load balancer"  
   - Visit the "LoadBalancer Ingress"

4) Get the name of the node-deployment pod and run: kubectl logs *name-of-node-pod* --follow  
   - This will show successful adds/deletes as they happen

# How to install the helm chart

1) For email, you have to set up AWS SES and use the username, password, and address from your SES in the command below.

  - The global.smtp.domain will be different because it has to be the DNS   name of the loadbalancer that the chart creates. This must be changed after the chart is created because the chart provisions the internal loadbalancer.

  - You'll have to create a Kubernetes secret named "smtp-password" that contains the password for your SES, the code for this follows:
      
	       apiVersion: v1
           kind: Secret
           metadata:
             name: smtp-password
           type: Opaque
           stringData:
             smtp-password: <YOUR SES PASSWORD>
    
   - Copy/paste that in a new file, smtp-password.yaml. 
   - Run kubectl apply -f smtp-password.yaml -n <YOUR NAMESPACE>
		
		
   Below is the command for installing the gitlab helm chart:
	
	helm install gitlab gitlab/gitlab 
	--timeout 600s 
	--set certmanager.install=false 
	--set global.ingress.configureCertmanager=false 
	--set global.smtp.enabled=true 
	--set global.smtp.password.secret=smtp-password 
	--set global.smtp.password.key=smtp-password 
	--set global.smtp.port=587 
	--set global.smtp.starttls_auto=true 
	--set global.smtp.domain=example.com 
	--set global.smtp.address=<ADDRESS TO YOUR SES>
	--set global.smtp.user_name=<SES USERNAME> 
	--set global.email.from=<YOUR EMAIL>
	--set global.email.reply_to=<YOUR EMAIL>
	--set global.smtp.authentication=login 
	--set global.smtp.tls=false 
	--set global.smtp.openssl_verify_mode=none 
	--set gitlab.name=example.com 
	--set global.hosts.gitlab.name=example.com
    --set global.ingress.tls.enabled=false 
    --set global.hosts.https=false 
    --set global.hosts.gitlab.https=false
    --set gitlab-runner.runners.privileged=true

  Everything that says `example.com` will need to be replaced with the address of the loadbalancer after the chart is created, so those can be left as `example.com`

2) After running the command above...
  - You'll need edit the service of type Loadbalancer. It should say it's pending before the edit
         
     --> `kubectl edit svc gitlab-nginx-ingress-controller`
   - It's special and needs the annotations below added under metadata.annotations:

       `service.beta.kubernetes.io/aws-load-balancer-internal: 'true'`
       `service.beta.kubernetes.io/aws-load-balancer-backend-protocol: tcp`
   - Run `kubectl get svc` to get the new loadbalancer address
   - Now that you have the address of the load balancer, you can run the same command from earlier except with `helm upgrade` instead of `helm install` with the new address in place of every `example.com`
   
3) Make sure all pods are running
  - Visit the address of the load balancer, you should see Gitlab
  - The first login will be with username: root
  - Get the password by running this command: 

     `kubectl get secret gitlab-gitlab-initial-root-password -o jsonpath='{.data.password}' | base64 --decode ; echo`
  - Configure sign-ups according to your standards
  - If your aws ses username, domain, and password are correct, email should already be configured correctly, create an account to test it out

4) Configuring the runner
  - HTTPS must be disabled for runners to work. This should be reflected in the values.yaml file
  - The install command consists of `global.hosts.https=false`, `global.hosts.gitlab.https=false` and `gitlab-runner.runners.privileged=true` which allow access for the runner.
  - The documentation for these and other globals is here: https://docs.gitlab.com/charts/charts/globals.html
   
