# Shopee Technical Test

The company is starting an engineering blog with Wordpress, and you are tasked to deploy the blog in the cloud. The blog is expected to have moderate baseline traffic, and occasional flash / spike traffic when we advertise the content to sites such as Hacker News, Slashdot, and Reddit (we write world-class blog posts that garner global interest).

## Stack

- GCP
- Bash Scripting

## Step

1. Prepare Google Cloud Account, setup billing account, setup project
2. Install some app dependencies:
   1. Google Cloud SDK `gcloud` : [https://cloud.google.com/sdk/install](https://cloud.google.com/sdk/install)
   2. Kubernetes Controller `kubectl` : [https://kubernetes.io/docs/tasks/tools/install-kubectl/](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
3. Clone this repository, and open it
   ```
   git clone https://github.com/rahmatnugr/shopee-tech-test.git
   cd shopee-tech-test
   ```
4. Run `login` command on script, for authentication initialization and project selection
   ```
   ./blog.sh login
   ```
5. Run `init` command to provision all infrastructure stack on GCP and deploy fresh wordpress

   ```
   ./blog.sh init
   ```

   After finish, it will output accessable public IP address for accessing wordpress

   ```
   Finish! Your wordpress IP address is accessable at http://34.107.218.216
   ```

6. To scale the wordpress app, use `resize`

   ```
   ./blog.sh resize [desired_num]
   ```

   Example:

   ```
   # scale to 3 instance
   ./blog.sh resize 3
   ```
