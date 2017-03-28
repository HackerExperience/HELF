#!/usr/bin/env groovy

node('elixir') {
  stage('Pre-build') {
    step([$class: 'WsCleanup'])

    env.BUILD_VERSION = sh(script: 'date +%Y.%m.%d%H%M', returnStdout: true).trim()
    def ARTIFACT_PATH = "${env.BRANCH_NAME}/${env.BUILD_VERSION}"

    checkout scm

    sh 'mix local.hex --force'
    sh 'mix local.rebar --force'
    sh 'mix clean'
    sh 'mix deps.get'

    stash name: 'source', useDefaultExcludes: false
  }

  stage('Build') {
    step([$class: 'WsCleanup'])

    unstash 'source'

    withEnv (['MIX_ENV=test']) {
      sh 'mix compile'
    }

    stash 'build'
  }
}

parallel (
  // 'Lint': {
  //   node('elixir') {
  //     stage('Lint') {
  //       step([$class: 'WsCleanup'])

  //       unstash 'source'
  //       unstash 'build'

  //       withEnv (['MIX_ENV=test']) {
  //         sh "mix credo --strict"
  //       }
  //     }
  //   }
  // },
  'Type validation': {
    node('elixir') {
      stage('Type validation') {
        step([$class: 'WsCleanup'])

        unstash 'build'

        // HACK: mix complains if I don't run deps.get again, not sure why
        sh "mix deps.get"

        // Reuse existing plt
        sh "cp ~/.mix/helf/*test*.plt* _build/test || :"

        withEnv (['MIX_ENV=test']) {
          sh "mix dialyzer --halt-exit-status"
        }

        // Store newly generated plt
        // Do it on two commands because we want it failing if .plt is not found
        sh "cp _build/test/*.plt ~/.mix/helf/"
        sh "cp _build/test/*.plt.hash ~/.mix/helf/"
      }

    }
  },
  'Tests': {
    node('elixir') {
      stage('Tests') {
        step([$class: 'WsCleanup'])

        unstash 'source'
        unstash 'build'

        withEnv (['MIX_ENV=test']) {
          // Unset debug flag, load env vars on ~/.profile & run mix test
          sh 'mix test'
        }
      }
    }
  }
)