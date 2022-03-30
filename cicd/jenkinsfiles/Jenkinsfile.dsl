pipelineJob('S3 Buckets') {
    definition {
        cpsScm {
            scm {
                git {
                    remote {
                        url("https://github.com/amoragon/cicd-practica-antonio.git")
                    }
                    branches("main")
                    scriptPath('Jenkinsfile.buckets')
                }
            }
        }
    }
}

pipelineJob('Check Buckets Size') {
    definition {
        cpsScm {
            scm {
                git {
                    remote {
                        url("https://github.com/amoragon/cicd-practica-antonio.git")
                    }
                    branches("main")
                    scriptPath('Jenkinsfile.cron')
                }
            }
        }
    }
}
