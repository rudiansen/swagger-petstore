#!/usr/bin/env groovy

def scanToken
def appVersion

pipeline {
    agent any

    parameters {
        // Optional parameter whether to perform SAST using Fortify ScanCentral        
        booleanParam(name: 'SCANCENTRAL_SAST', 	defaultValue: params.SCANCENTRAL_SAST ?: false,
                description: 'Run a remote scan using Scan Central SAST (SCA) for Static Application Security Testing')        
        // Optional parameter whether to upload scan artifact to Fortify SSC
        booleanParam(name: 'UPLOAD_TO_SSC',		defaultValue: params.UPLOAD_TO_SSC ?: false,
                description: 'Enable upload of scan results to Fortify Software Security Center')               

        // === Parameters used for deployment using Octopus Deploy ===
        // The space ID that we will be working with. The default space is typically Spaces-1.
        // string(defaultValue: 'Spaces-1', description: '', name: 'SpaceId', trim: true)
        // The Octopus project we will be deploying.
        // string(defaultValue: 'Swagger-PetStore', description: '', name: 'ProjectName', trim: true)
        // The environment we will be deploying to.
        // string(defaultValue: 'Dev', description: '', name: 'EnvironmentName', trim: true)
        // The name of the Octopus instance in Jenkins that we will be working with. This is set in:
        // Manage Jenkins -> Configure System -> Octopus Deploy Plugin
        // string(defaultValue: 'Octopus Deploy', description: '', name: 'ServerId', trim: true)

        // === Parameters used for deployment using Terraform ===
        string(name: 'environment', defaultValue: 'dev', description: 'environment file to use for deployment')           
        booleanParam(name: 'autoApprove', defaultValue: 'true', description: 'Automatically run apply after generating plan?')
    }
    
    environment {
        // Application settings
        APP_NAME = "Swagger-PetStore"             
        COMPONENT_NAME = "swagger-petstore"
        GIT_URL = "https://github.com/rudiansen/swagger-petstore"                

        // The following are defaulted and can be overriden by creating a "Build parameter" of the same name
        SSC_URL = "${params.SSC_URL ?: 'http://10.87.1.12:8080/ssc'}" // URL of Fortify Software Security Center
        SSC_APP_VERSION_ID = "${params.SSC_APP_VERSION_ID ?: '1001'}" // Id of Application in SSC to upload results to        
        SSC_SENSOR_POOL_UUID = "${params.SSC_SENSOR_POOL_UUID ?: '00000000-0000-0000-0000-000000000002'}" // UUID of Scan Central Sensor Pool to use - leave for Default Pool
    }

    stages {
        stage('Build') {            
            steps {
                // Get some code from a GitHub repository                
                git branch: 'poc-sss', url: "${env.GIT_URL}"                

                // Get Git commit details
                script {
                    if (isUnix()) {
                        sh 'git rev-parse HEAD > .git/commit-id'
                    } else {
                        bat(/git rev-parse HEAD > .git\\commit-id/)
                    }
                    
                    env.GIT_COMMIT_ID = readFile('.git/commit-id').trim()                    

                    println "Git commit id: ${env.GIT_COMMIT_ID}"                    

                    // Run maven to build WAR/JAR application
                    if (isUnix()) {
                        sh 'mvn "-Dskip.unit.tests=false" -Dtest="*Test,!PasswordConstraintValidatorTest,!UserServiceTest,!DefaultControllerTest,!SeleniumFlowIT" -DfailIfNoTests=false -B clean verify package --file pom.xml'
                    } else {
                        bat "mvn \"-Dskip.unit.tests=false\" Dtest=\"*Test,!PasswordConstraintValidatorTest,!UserServiceTest,!DefaultControllerTest,!SeleniumFlowIT\" -DfailIfNoTests=false -B clean verify package --file pom.xml"
                    }

                    // Get app version from pom.xml file
                    appVersion = sh script: 'mvn help:evaluate -Dexpression=project.version -q -DforceStdout', returnStdout: true
                }
            }

            post {
                success {                   
                    // Archive the built file
                    archiveArtifacts "target/${env.COMPONENT_NAME}-${appVersion}.war"
                    // Stash the deployable files
                    stash includes: "target/${env.COMPONENT_NAME}-${appVersion}.war", name: "${env.COMPONENT_NAME}-${appVersion}_release"
                }
            }
        }

        stage('Fortify ScanCentral - SAST') {           
            steps {
                script {
                    // Run Maven debug compile, download dependencies (if required) and package up for ScanCentral
                    if (isUnix()) {
                        sh "mvn -Dmaven.compiler.debuglevel=lines,vars,source -DskipTests -P fortify clean verify"
                        sh "mvn dependency:build-classpath -Dmdep.regenerateFile=true -Dmdep.outputFile=${env.WORKSPACE}/cp.txt"
                    } else {
                        bat "mvn -Dmaven.compiler.debuglevel=lines,vars,source -DskipTests -P fortify clean verify"
                        bat "mvn dependency:build-classpath -Dmdep.regenerateFile=true -Dmdep.outputFile=${env.WORKSPACE}/cp.txt"
                    }

                    // read contents of classpath file
                    def classpath = readFile "${env.WORKSPACE}/cp.txt"
                    println "Using classpath: $classpath"

                    if (params.SCANCENTRAL_SAST) {

                        // set any standard remote translation/scan options
                        fortifyRemoteArguments transOptions: '',
                                scanOptions: ''

                        if (params.UPLOAD_TO_SSC) {
                            // Remote analysis (using Scan Central) and upload to SSC
                            fortifyRemoteAnalysis remoteAnalysisProjectType: fortifyMaven(buildFile: 'pom.xml'),
                                remoteOptionalConfig: [                                            
                                    sensorPoolUUID: "${env.SSC_SENSOR_POOL_UUID}"
                                ],
                                uploadSSC: [appName: "${env.APP_NAME}", appVersion: "${env.SSC_APP_VERSION_ID}"]                                                                                                                                     

                        } else {
                            // Remote analysis (using Scan Central)
                            fortifyRemoteAnalysis remoteAnalysisProjectType: fortifyMaven(buildFile: 'pom.xml'),
                                remoteOptionalConfig: [                                            
                                    sensorPoolUUID: "${env.SSC_SENSOR_POOL_UUID}"
                                ]
                        }                    
                    } else {
                        println "No Static Application Security Testing (SAST) to do."
                    }                   

                    script {
                        // Populate scanCentral token for retrieving scan status                    
                        def matcher = manager.getLogMatcher('^.*received token:  (.*)$')

                        if (matcher.matches()) {
                            scanToken = matcher.group(1)
                        
                            if (scanToken != null) {
                                println "Received scan token: ${scanToken}"                               
                            }
                        }
                    }                                                           
                }
                
                // Write scan token to a file
                writeFile(file: 'scantoken.txt', text: "${scanToken}")

                // Print list of files to check whether the scantoken.txt file exists
                sh 'ls -al ./'

                // Read scan token from the new created file
                sh 'cat ./scantoken.txt'

                //  Check scanning status until it's completed                
                pwsh label: 'Check ScanCentral scan status', returnStatus: true, script: './powershell/scancentral_scan_status_check.ps1'                                      
            }
        }

        stage("Publish Docker Image to Nexus Repository") {            
            steps {
                // Create archive file (.tar) for docker image build process
                sh 'tar --create --exclude=\'.git*\' --exclude=\'*.tar\' --file swagger-petstore.tar *'

                // Execute script for docker image build and push to Nexus Repository using Docker REST API
                pwsh label: 'Docker image build and publish to Nexus Repository', returnStatus: true, script: './powershell/docker_build_and_push_image.ps1 -AppVersion ' + "${appVersion}"
            }
        }

        stage("Initialize Terraform"){
            // Run Terraform command on kubectl node
            agent {label 'kubectl'}

            steps {
                script {
                    // Set Terraform path
                    def tfHome = tool name: 'Terraform'
                    env.PATH = "${tfHome}:${env.PATH}"
                }

                sh 'terraform version'
                // Change working directory to terraform
                dir("terraform") {
                    sh 'pwd'
                    sh 'terraform init'                
                    sh "terraform plan -out tfplan -var-file=environments/${params.environment}.tfvars"
                    sh "terraform show -no-color tfplan > ${env.WORKSPACE}/terraform/tfplan.txt"
                }                                                
            }
        }

        stage("Deployment Approval") {
            when {
                not {
                    equals expected: true, actual: params.autoApprove
                }
            }

            steps {
                script {
                    def plan = readFile "${env.WORKSPACE}/terraform/tfplan.txt"
                    input message: "Do you want to apply the plan?",
                        parameters: [text(name: 'Plan', description: 'Please review the plan', defaultValue: plan)]
                }
                
                post {
                    always {
                        archiveArtifacts artifacts: "${env.WORKSPACE}/terraform/tfplan.txt"
                    }
                }
            }
        }

        stage("Apply Deployment using Terraform") {
            // Run Terraform command on kubectl node
            agent {label 'kubectl'}

            steps {
                // Change working directory to terraform
                dir("terraform") {
                    sh 'terraform apply -input=false tfplan'
                }                
            }
        }

        // stage("Deployment using Octopus Deploy") {
        //     steps {
        //         // Add Octopus CLI tools
        //         sh "echo \"OctoCLI: ${tool('Default')}\""

        //         octopusCreateRelease additionalArgs: '', cancelOnTimeout: false, channel: '', defaultPackageVersion: '', deployThisRelease: false, deploymentTimeout: '', environment: "${EnvironmentName}", jenkinsUrlLinkback: false, project: "${ProjectName}", releaseNotes: false, releaseNotesFile: '', releaseVersion: "${appVersion}-${BUILD_NUMBER}", serverId: "${ServerId}", spaceId: "${SpaceId}", tenant: '', tenantTag: '', toolId: 'Default', verboseLogging: false, waitForDeployment: false
        //         octopusDeployRelease cancelOnTimeout: false, deploymentTimeout: '', environment: "${EnvironmentName}", project: "${ProjectName}", releaseVersion: "${appVersion}-${BUILD_NUMBER}", serverId: "${ServerId}", spaceId: "${SpaceId}", tenant: '', tenantTag: '', toolId: 'Default', variables: '', verboseLogging: false, waitForDeployment: true                                
        //     }
        // }

        stage("Fortify WebInpsect - DAST") {
            steps {
                // Execute PowerShell script for WebInspect REST API scanning
                pwsh label: 'DAST with Fortify WebInspect', returnStatus: true, script: './powershell/webinspect_automation.ps1'
            }
        }
    }    
}
