/**
 * Define utility functions.
 */

def demoAppName(branchname) {
    def appname = branchname[6..-1].replaceAll('_', '-')
    return "bedrock-demo-${appname}".toString()
}

def demoAppURL(appname) {
    if ( appname ==~ /^bedrock-demo-[1-5]$/ ) {
        return "https://www-demo${appname[-1]}.allizom.org"
    }
    return "https://${appname}.us-west.moz.works"
}

/**
 * Send a notice to #www on irc.mozilla.org with the build result
 *
 * @param stage step of build/deploy
 * @param result outcome of build (will be uppercased)
*/
def ircNotification(config, Map args) {
    def command = "bin/irc-notify.sh --irc_nick '${config.irc.nick}' --irc_channel '${config.irc.channel}'"
    for (arg in args) {
        command += " --${arg.key} '${arg.value}'"
    }
    sh command
}

def buildDockerImage(Map kwargs) {
    def update = kwargs.update ? 'true' : 'false'
    def repo = kwargs.dockerRepo ?: 'mozorg'
    def script = kwargs.script ?: 'build_image.sh'
    def environs = ["UPDATE_DOCKER_IMAGES=${update}",
                    "DOCKERFILE=${kwargs.dockerfile}",
                    "DOCKER_REPOSITORY=${repo}/${kwargs.dockerfile}"]
    if (kwargs.fromDockerfile) {
        environs << "FROM_DOCKER_REPOSITORY=${repo}/${kwargs.fromDockerfile}"
    }
    withEnv(environs) {
        sh "docker/jenkins/${script}"
    }
}

def includeDockerData(name, from_name, command, repo='mozorg') {
    withEnv([
        "DOCKER_REPOSITORY=${repo}/${name}",
        "FROM_DOCKER_REPOSITORY=${repo}/${from_name}",
        "DOCKER_DATA_COMMAND='${command}'",
    ]) {
        sh "docker/jenkins/include_data.sh"
    }
}

def pushDockerhub(from_repo, to_repo='') {
    to_repo = to_repo ?: from_repo
    withCredentials([[$class: 'StringBinding',
                      credentialsId: 'DOCKER_PASSWORD',
                      variable: 'DOCKER_PASSWORD']]) {
        withEnv(['DOCKER_USERNAME=mozjenkins',
                 "FROM_DOCKER_REPOSITORY=${from_repo}",
                 "DOCKER_REPOSITORY=${to_repo}"]) {
            retry(2) {
                sh 'docker/jenkins/push2dockerhub.sh'
            }
        }
    }
}

def pushPrivateReg(port, apps) {
    retry(3) {
        withEnv(['FROM_DOCKER_REPOSITORY=mozorg/bedrock_l10n',
                 "PRIVATE_REGISTRIES=localhost:${port}",
                 "DEIS_APPS=${apps.join(',')}"]) {
            sh 'docker/jenkins/push2privateregistries.sh'
        }
    }
}

def integrationTestJob(propFileName, appURL) {
    def testsBaseDir = 'docker/jenkins/properties/integration_tests'
    def testsFileExt = '.properties'
    return {
        node {
            unstash 'scripts'
            unstash 'tests'
            def fullFilename = "${testsBaseDir}/${propFileName}${testsFileExt}"
            def testScript = "docker/jenkins/run_integration_tests.sh ${fullFilename}".toString()
            withCredentials([[$class: 'UsernamePasswordMultiBinding',
                              credentialsId: 'SAUCELABS_CREDENTIALS',
                              usernameVariable: 'SAUCELABS_USERNAME',
                              passwordVariable: 'SAUCELABS_API_KEY']]) {
                withEnv(["BASE_URL=${appURL}",
                         "SELENIUM_VERSION=2.52.0"]) {
                    try {
                        sh testScript
                    }
                    finally {
                        junit 'results/*.xml'
                    }
                }
            }
        }
    }
}

return this;
