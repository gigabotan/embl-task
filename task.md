**Technical Exercise: Kubernetes Cluster Deployment and Management**

As part of our recruitment process, we would like to present you with a hands-on technical exercise designed to assess your skills in Kubernetes cluster management, application deployment, and version upgrade processes. This exercise offers a glimpse into the practical challenges you may encounter in the role you're applying for.

**Objective**

Your aim is to configure a Kubernetes cluster using RKE2, consisting of one master node and one worker node, on provided virtual machines (VMs) with a basic operating system pre-installed. You will deploy the cluster using version 1.27, any minor version will do. After a successful deployment and configuration of the cluster, we would like you to deploy a WordPress application to demonstrate the operational capabilities of your setup.

**Infrastructure Provided**

- **Bastion VM**: This VM serves as your initial point of access to the cluster environment. You will connect to the other VMs through this bastion. 
    
- **Master VM**: This virtual machine is designated to function as the master node of your Kubernetes cluster.
    
- **Worker VM**: This VM is intended to be used as the worker node in your cluster.
    
- **Network connectivity**: All vms have outbound connectivity to the Internet, but only the bastion is reachable via a public ip address. All inbound and outbound connections are allowed in each vm to cater for any creative solutions to be implemented.
    

**Instructions**

1. **Cluster Creation**: Utilising RKE2, set up a Kubernetes cluster comprising the provided VMs (1 master and 1 worker) beginning with version 1.27. Ensure that the cluster reaches a fully operational state, capable of executing kubectl commands successfully from the bastion node.
    
2. **Application Deployment**: Deploy a WordPress application to your cluster. Detail all deployment steps, including any YAML configuration files used. Verify that the application is accessible and functioning by providing evidence of the WordPress website. Consider deploying any other tools you find necessary.
    
3. [BONUS] **Cluster Upgrade**: Upgrade your Kubernetes cluster to version 1.28. Outline the upgrade procedure, aiming for minimal downtime, and make sure that the WordPress application remains active and functional before, during, and after the upgrade.
    

**Submission Guidelines**

Document all steps taken throughout the exercise, including command-line inputs and outputs, configurations, and any troubleshooting or considerations accounted for during the deployment and upgrade processes. Your submission should be a comprehensive narrative of your approach, coupled with the challenges encountered and how they were addressed. Please send your documentation as a PDF file to [Dhyana Cremer](mailto:cremer@ebi.ac.uk) by 27/03 at 17:00 UK time including references to code and external documentation used.

For questions or further clarifications, please reach out to us by writing to [Dhyana Cremer](mailto:cremer@ebi.ac.uk).

We wish you the best of luck! We look forward to looking at your expertise and approach to tackling this Kubernetes challenge.