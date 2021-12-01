#!/usr/bin/env groovy

def scanToken

pipeline {
    agent any

    parameters {        
        booleanParam(name: 'SCANCENTRAL_SAST', 	defaultValue: params.SCANCENTRAL_SAST ?: false,
                description: 'Run a remote scan using Scan Central SAST (SCA) for Static Application Security Testing')        
        booleanParam(name: 'UPLOAD_TO_SSC',		defaultValue: params.UPLOAD_TO_SSC ?: false,
                description: 'Enable upload of scan results to Fortify Software Security Center')        
        booleanParam(name: 'USE_DOCKER', defaultValue: params.USE_DOCKER ?: false,
                description: 'Package the application into a Dockerfile for running/testing')
        booleanParam(name: 'RELEASE_TO_NEXUSREPO', defaultValue: params.RELEASE_TO_NEXUSREPO ?: false,
                description: 'Release built and tested image to Nexus Repository')
    }
    
    environment {
        // Application settings
        APP_NAME = "Swagger-PetStore"
        APP_VER = "1.0.7"     
        COMPONENT_NAME = "swagger-petstore"
        GIT_URL = scm.getUserRemoteConfigs()[0].getUrl()
        JAVA_VERSION = 8

        // Credential references        
        //SSC_AUTH_TOKEN = credentials('iwa-ssc-ci-token-id')    

        // The following are defaulted and can be overriden by creating a "Build parameter" of the same name
        SSC_URL = "${params.SSC_URL ?: 'http://10.87.1.12:8080/ssc'}" // URL of Fortify Software Security Center
        SSC_APP_VERSION_ID = "${params.SSC_APP_VERSION_ID ?: '1001'}" // Id of Application in SSC to upload results to        
        SSC_SENSOR_POOL_UUID = "${params.SSC_SENSOR_POOL_UUID ?: '00000000-0000-0000-0000-000000000002'}" // UUID of Scan Central Sensor Pool to use - leave for Default Pool        
    }

    stages {
        stage('Build') {            
            steps {
                // Get some code from a GitHub repository                
                git branch: 'poc-sss', url: 'https://github.com/rudiansen/swagger-petstore'

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
                    // if (isUnix()) {
                    //     sh 'mvn "-Dskip.unit.tests=false" -Dtest="*Test,!PasswordConstraintValidatorTest,!UserServiceTest,!DefaultControllerTest,!SeleniumFlowIT" -DfailIfNoTests=false -B clean verify package --file pom.xml'
                    // } else {
                    //     bat "mvn \"-Dskip.unit.tests=false\" Dtest=\"*Test,!PasswordConstraintValidatorTest,!UserServiceTest,!DefaultControllerTest,!SeleniumFlowIT\" -DfailIfNoTests=false -B clean verify package --file pom.xml"
                    // }
                }
            }

            post {
                success {                   
                    // Archive the built file
                    archiveArtifacts "target/${env.COMPONENT_NAME}-${env.APP_VER}.war"
                    // Stash the deployable files
                    stash includes: "target/${env.COMPONENT_NAME}-${env.APP_VER}.war", name: "${env.COMPONENT_NAME}-${env.APP_VER}_release"
                }
            }
        }

        stage('Fortify ScanCentral Scan - SAST') {           
            steps {
                script {
                    // Get code from Git repository so we can recompile it                    
                    // git branch: 'poc-sss', url: 'https://github.com/rudiansen/swagger-petstore'

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

                    // Delete scantoken.txt file
                    sh 'rm ./scantoken.txt'
                    
                    // Populate scanCentral token for retrieving scan status
                    script {
                        def matcher = manager.getLogMatcher('^.*received token:  (.*)$')

                        if (matcher.matches()) {
                            scanToken = matcher.group(1)
                        
                            if (scanToken != null) {
                                println "Received scan token: ${scanToken}"
                                // Write scan token to a file
                                echo '"${scanToken}" > ./scantoken.txt'                                                            
                            }
                        }
                    }

                    // Print list of files in current working directory
                    pwsh 'Get-ChildItem ./'

                    pwsh 'Get-Content "./scantoken.txt"'

                    //  Check scanning status until it's completed
                    pwsh '/home/fortify/bin/scancentral -url http://10.87.1.12:8090/scancentral-ctrl status -token (Get-Content "./scantoken.txt")'

                    script {
                        checkScanStatus()
                    }
                }                        
            }
        }

        stage("App Deployment using Octopus Deploy") {
            steps {

                pwsh 'Write-Output "The steps for Octopus Deployment go here..."'
            }
        }

        stage("WebInpsect Scan - DAST") {
            steps {
                // Execute PowerShell script for WebInspect REST API scanning
                pwsh returnStatus: true, script: './powershell/webinspect_automation.ps1'
            }
        }
    }    
}

def checkScanStatus() {
    def matcher1 = manager.getLogMatcher('^The job state is:  (.*)$')
    def matcher2 = manager.getLogMatcher('^SSC upload state is:  (.*)$')

    println "The job status is: ${matcher1}"
    println "SSC upload state is: ${matcher2}"

    if (!matcher1.matches() && !matcher2.matches()) {
        //  Check scanning status until it's completed
        pwsh '/home/fortify/bin/scancentral -url http://10.87.1.12:8090/scancentral-ctrl status -token (Get-Content "./scantoken.txt")'

        checkScanStatus()
    }
}