# Introduction

This repository will outline the required steps to integrate Gitlab and Icinga2 for configuration managment.

This is a useful option for either a small or large Icinga2 installation as managing hosts or templates though Gitlab is an easy way to manage changes to files, delegate changes, revert back changes, etc.

For now, I am focusing on the integration with Gitlab and the Gitlab runner with Docker, however this may apply to other Git platforms.

Also, I am not going to go into the installation of Icinga2, Gitlab or the Gitlab runner, there is plenty of documentation out there 
on how to install these products.

If you feel you can help improve this setup, please feel free to submit an issue or a pull request with your suggestions.

# Todo

Some things I'd like to improve:

* ~~Pull less files from apt repositories when jobs run (maybe a custom docker image?)~~
  * Done!  This makes verifying and deploying a lot faster :smiley:
    * https://github.com/mzac/icinga2-check-config/blob/master/Dockerfile
    * https://github.com/mzac/icinga2-push-config/blob/master/Dockerfile
    * Note: you can still use the debian image .gitlab-ci.yml if you prefer: https://github.com/mzac/gitlab-icinga2-ci-cd/blob/master/gitlab-ci.yml.debian-image
* Improve on the script that runs on the Icinga2 server for better error checking
* Add Icingaweb2 screenshots to show what is happening
* Find a way to push config changes to Icinga2 running on Windows - might need some help here!
* Look at uploading configuration to Icinga2 via API and configuration packages
  * https://www.icinga.com/docs/icinga2/latest/doc/12-icinga2-api/#icinga2-api-config-management

# Requirements

* Icinga2 server on Linux - https://www.icinga.com
* Gitlab server - https://www.gitlab.com
* Docker - https://www.docker.com
* Gitlab runner - https://docs.gitlab.com/runner/
* Access to a Linux CLI

# Setting up a Project

On your Gitlab installation, create a Project that will contain your Icinga2 configuration files.  

* Note: You can create directories if you'd to make it easier to track your files, such as a directory for servers, routers, templates, etc.  Icinga2 will parse through directories and load all *.conf files

![Gitlab - New Project](/images/new_project.png)

Once you have created your Project to host your Icinga2 configuration files, create your first config file.

![Gitlab - New File](/images/new_file.png)

* Note: If you already have a directory on your Icinga2 server and you want to load all the files into Gitlab into the new
project, follow the instructions in the new Project under the 'Existing Foler' section

For our first test, we will create *server1.conf* and have it ping localhost/127.0.0.1

![Gitlab - server1](/images/server1.png)

```
object Host "server1" {
    import "generic-host"
    address = "127.0.0.1"
}
```

* Note: In this example we created a simple .conf file for a host, however your conf files may contain any type of object that Icinga2 supports
* https://www.icinga.com/docs/icinga2/latest/doc/09-object-types/

# Create runner script

We are also going to create a script that will reside on the Icinga2 server and will be called by Gitlab via SSH to pull any updates and reload the configuration.  If the script detects that no .conf files were modified, Icinga2 will not be reloaded.

Follow the same steps as above to create another file named *gitlab-icinga2-cd.sh* residing in the root directory of your project.

```
#!/bin/bash

cd /etc/icinga2/conf.d/private

export GIT_OUTPUT=`git pull`

if [[ $GIT_OUTPUT = *".conf"* ]]; then
  echo "Changes made, reloading Icinga2"
  systemctl reload icinga2
else
  echo "No changes made, NOT reloading Icinga2"
fi
```

* Note: You may choose a different directory that I have specified (/etc/icinga2/conf.d/private), please make sure to set it to the directory where you want to store your Icinga2 config files.  Also, depending on your installation, if you're not running as 'root', you may need to add a 'sudo' command before the 'systemctl reload icinga2'

# Cloning the project

Now that we have created our Project and our first configuration file, we need to clone our project

* How to clone project: https://docs.gitlab.com/ee/gitlab-basics/command-line-commands.html#clone-your-project

```
cd /etc/icinga2/conf.d
mkdir private
cd private
git clone git@<git server>:<gitlab username>/icinga2-configuration.git .
```

Now that the files are cloned, go ahead and reload Icinga2 and you should see the server we created through Gitlab in the Icingaweb2 interface.

```
systemctl reload icinga2
```

# Changing the script to executable

AFAIK, there is no easy way though the Gitlab GUI to change files to executable, so we need to fix the permissons on the 'gitlab-icinga2-cd.sh' script and then upload it back to the Gitlab server.

```
cd /etc/icinga2/conf.d/private
chmod a+x gitlab-icinga2-cd.sh
git add .
git commit -m "Change permissions on gitlab-icinga2-cd.sh to executable"
git push -u origin master
```

# Generate SSH keys

* Instructions here too: https://www.digitalocean.com/community/tutorials/how-to-set-up-ssh-keys--2

At this point we need to generate some SSH keys so that the Docker instance that will run in the Gitlab runner can push the config to the Icinga2 server.

Drop to a linux cli and execute the following making sure to specify the file '/tmp/gitlab-icinga2-ssh' where we want the keys we generate to be generated.

```
root@localhost:~# ssh-keygen
Generating public/private rsa key pair.
Enter file in which to save the key (/root/.ssh/id_rsa): /tmp/gitlab-icinga2-ssh
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /tmp/gitlab-icinga2-ssh.
Your public key has been saved in /tmp/gitlab-icinga2-ssh.pub.
The key fingerprint is:
SHA256:ombFx51e0vLUOQJuvHx1od7G+1+ZDPEi5nUWcULD1Wg root@02c9f4707abf
The key's randomart image is:
+---[RSA 2048]----+
|             o+++|
|              Eo+|
|          .  o o |
|     . . + + .+.o|
|      + S Oo===+.|
|     o o +oB+oOoo|
|    +     +.o. B.|
|   o       .  . o|
|               .=|
+----[SHA256]-----+
```

# Deploy SSH key

Now that we have the public and private keys generated, we need to put them in the right place.

To deploy the public key to our production Icinga2 server, look at your file and copy the contents to clipboard:

* Note, please generate your own keys, do not use these example keys!!!

Example:
```
root@localhost:~# cat /tmp/gitlab-icinga2-ssh.pub
ssh-rsa <ssh public key> root@localhost
```

It should look like this:
```
root@localhost:~# cat /tmp/gitlab-icinga2-ssh.pub
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDMPFp66Hk4txKZHOZ97sYyuhqYKfzork6uZdBiJ7VEkDQxqR3xHz8Qz67Z19je/oVCPxEKajdQfcm8a0CWXstfnDa2zO4pqfj7Y3LRDW15fmqdNCa6/I0K0XMX8tsUgFgnwsn+O4jn/8p/fq815pWiGWRIPaOYfX8CtXZerq32QujonWFJYhwjYYK9PUYnWg9T/7miMNcjK6/i/l8r/5tD3TIp6yyZgiwEJtiETh9zvDKLPTkjPSnyc+Gtb9kumZ1kiZOX84iOS/EsVQkgMtKsAGNGD6+oCK1cbXikW9VEOm0pwxTYb0ySr/KNlGeJge5gj2kYDNJJ+cmGN0+MHbAf root@localhost
```

Now we are ready to deploy the public key on your Icinga2 server:

Example:
```
root@icinga2-prod:~# mkdir /root/.ssh
root@icinga2-prod:~# echo "ssh-rsa <ssh public key> root@localhost" >> /root/.ssh/authorized_keys
```

It should look like this:
```
root@icinga2-prod:~# mkdir /root/.ssh
root@icinga2-prod:~# echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDMPFp66Hk4txKZHOZ97sYyuhqYKfzork6uZdBiJ7VEkDQxqR3xHz8Qz67Z19je/oVCPxEKajdQfcm8a0CWXstfnDa2zO4pqfj7Y3LRDW15fmqdNCa6/I0K0XMX8tsUgFgnwsn+O4jn/8p/fq815pWiGWRIPaOYfX8CtXZerq32QujonWFJYhwjYYK9PUYnWg9T/7miMNcjK6/i/l8r/5tD3TIp6yyZgiwEJtiETh9zvDKLPTkjPSnyc+Gtb9kumZ1kiZOX84iOS/EsVQkgMtKsAGNGD6+oCK1cbXikW9VEOm0pwxTYb0ySr/KNlGeJge5gj2kYDNJJ+cmGN0+MHbAf root@localhost" >> /root/.ssh/authorized_keys
```

Now we need to copy over the private key to put into our Gitlab project:

* Note: Again, PLEASE generate your own keys, do not use these example keys!!!

```
root@localhost:~# cat /tmp/gitlab-icinga2-ssh
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAzDxaeuh5OLcSmRzmfe7GMroamCn86K5OrmXQYie1RJA0Makd
8R8/EM+u2dfY3v6FQj8RCmo3UH3JvGtAll7LX5w2tszuKan4+2Ny0Q1teX5qnTQm
uvyNCtFzF/LbFIBYJ8LJ/juI5//Kf36vNeaVohlkSD2jmH1/ArV2Xq6t9kLo6J1h
SWIcI2GCvT1GJ1oPU/+5ojDXIyuv4v5fK/+bQ90yKessmYIsBCbYhE4fc7wyiz05
Iz0p8nPhrW/ZLpmdZImTl/OIjkvxLFUJIDLSrABjRg+vqAitXG14pFvVRDptKcMU
2G9Mkq/yjZRniYHuYI9pGAzSSfnJhjdPjB2wHwIDAQABAoIBAQC8Ut6fvOOif3Vf
yD1lXBpYRjElpHn32FrnBy0KhVDpgwsNy8K3Rzew+cBiUV1B6nHYbyz4bI7K4uJ1
onQw9AIWDIaLMxZdRsU2kTIbQIV05TPL933LJ/uqQQ4exCptkhc3uq7lheItAzmn
LJrFWfUaPs2wq13By96lEcyva+UvUEcn0X1Yo5yJhupgPRZljGlQDnChvOiai4km
3Gyh9dZ96bh7CpRymcDQM9G0byjfbAQCIF7+X3cxx2U+gMUOrNgptyu36335kPIV
kwfJG0bl8m7eF9Ee4j65cIo3H2CA7bv2kXLbMOeQ8qYmj9dBCODl4COcDt9pFFrk
GWf4xMDpAoGBAO+7SyPrqKe3vfnqwhVxQ4C/7GlqIgkRkB307GQMk67CLhZ1+UDf
8zFi/0DZU/nkQtnnH+RDYhauqpfm4j7nx/O9mgF10m00fgQ1AK3xXmGkxmPOPEfb
KbtKOnabgP+kosliIaVi2qgkS/ql1QtvUtbNxGIPddKxgICaIOLtGkfrAoGBANoY
aaYBPTWeH9WjIGjGce3Ng/+h3kXvdonD2ow2Uy2WxFE//HrLY1KmdKvRjp8Lde0A
fy8RLjjBI2SQ5IYK4G06cK5WecE4a0CiQtvnlaXT5h8IxjIruRAFykomQ7Zp7CYe
edd7SsatdWvXeM9uG4MyL4AfDXRN2nxEiOMZdn+dAoGALnPRVI2GabFN645Uu0ju
NpV53tdE7xLrJRLfd2eEelmACrQjbzG18vzmzw8NmZ9kYMrLQDTaXeDMh5CiiGPr
N8ymed/1vVltja0ji5D4o90E4DQHNDlAdd0lRPRO47poHLOaJ2znR6t42YGmrYeN
ure2dPXf88qXRtQWyUH+VK8CgYBXic71+69W0xYSCPzcMTLPcVsXAyCVT41ztHIH
L1LpjIdV2Wn826ANL5TK1jz5p3741uc1vB6iVxtepS2kg78a+Ib74ufR31RlR/uw
Cl8thUTrlfj/cD9CqCBO7Nbm49MOZdMf43PbFQp5c64hDB/s4/re4RfkY89ba6LK
DJFcnQKBgGQOMmpovd3wcZILiHYcb32O8y1jUYQk88hQH/LMeGJpFtppEJQKggeB
Uz1aQUgE0LXhWiaaC4mi6HJM+AVMApfqqsDX1OFzSdJvzmEdBKkVTgraDZEOTX9I
bIWtUU081vklopv8UxQk2YIrDD4PtDBlAASMEoJHmPEnsC7b3dKN
-----END RSA PRIVATE KEY-----
```

Copy ~~this~~ YOUR private key to your clipboard and go back to your Gitlab project.

# Gitlab variables

Now that we have the private key, we need to add it into our project as a 'variable'.

In your project, go to:

* Settings -> CI / CD
* Expand Secret variables

Enter in the following variables:

* SSH_PRIVATE_KEY - Paste in the private key
* SSH_USER - Username we will use to login to the Icinga2 server (usually 'root')
* ICINGA_SERVER - The IP/DNS Name of your Icinga2 server
* ICINGA_CONFIG_DIR - The directory where your Icinga2 config lives as well as the 'gitlab-icinga2-cd.sh' script

* Note: The order that you put the variables in does not matter.

![Gitlab - variables](/images/variables.png)

Once you have put them all in, click on 'Hide values' and then on 'Save variables'.

# Gitlab .gitlab-ci.yml configuration file

We are now ready to provide our project with the '.gitlab-ci.yml' file.  This file will tell Gitlab what to do when we make commits to our project.

* Read more here: https://docs.gitlab.com/ee/ci/quick_start/

As we did before when we created our first server, create a new file and name it '.gitlab-ci.yml' (yes, with a leading 'dot .').

```yaml
stages:
  - test
  - deploy

Test Icinga2 Config:
  image: mzac23/icinga2-check-config
  stage: test
  script:
    # check if variables are set in gitlab project
    - if [ -z "$SSH_PRIVATE_KEY" ]; then exit 1; fi
    - if [ -z "$SSH_USER" ]; then exit 1; fi
    - if [ -z "$ICINGA_SERVER" ]; then exit 1; fi
    - if [ -z "$ICINGA_CONFIG_DIR" ]; then exit 1; fi
    # Copy config from Gitlab to Icinga2 test dir
    - mkdir /etc/icinga2/conf.d/test-config
    - cp -a -R * /etc/icinga2/conf.d/test-config
    # Verify Icinga2 config
    - icinga2 daemon -C
    
Deploy to Icinga2 Production:
  image: mzac23/icinga2-push-config
  stage: deploy
  script:
    # Setup ssh key
    - mkdir -p ~/.ssh
    - echo "$SSH_PRIVATE_KEY" | tr -d '\r' > ~/.ssh/id_rsa
    - chmod 700 ~/.ssh/id_rsa
    - eval "$(ssh-agent -s)"
    - ssh-add ~/.ssh/id_rsa
    - ssh-keyscan -H $ICINGA_SERVER >> ~/.ssh/known_hosts
    # Copy Icinga2 config to prod server
    - ssh $SSH_USER@$ICINGA_SERVER $ICINGA_CONFIG_DIR/gitlab-icinga2-cd.sh
  only:
    # Only push changes to prod server on the master branch
    - master
```

* Note: This setup uses two custom Docker images, but you can still use the debian image .gitlab-ci.yml if you prefer: https://github.com/mzac/gitlab-icinga2-ci-cd/blob/master/gitlab-ci.yml.debian-image


As soon as you save this file, your Gitlab will start to run this job.  Under the CI / CD -> Jobs menu, you should see something happening:

![Gitlab - job passed](/images/job_passed.png)

If something goes wrong, the job might fail:

![Gitlab - job failed](/images/job_failed.png)

If you click ont the 'Passed' for 'Failed' box you will see a terminal that will explain what worked or what went wrong.

Here are examples of the 'Passed' jobs for the 'Test' and 'Deploy' stages:

Test:
![Gitlab - job passed test](/images/job_terminal_passed_test.png)

Deploy:
![Gitlab - job passed deploy](/images/job_terminal_passed_deploy.png)

Here is an example of a 'Failed' job for the 'Test' stage.  When this stage fails, the process stops and nothing gets deployed to the Icinga2 server.  For this example, a configuration file was created with invalid data:

![Gitlab - job failed test](/images/job_terminal_failed_test.png)

# Conclusion

Now that our job has run, any new .conf files that we add through Gitlab will be automatially verified and checked for
configuration errors.  Once verifications are done, they are pushed to our production Icinga2 server and the server is
reloaded with the new config.
