#!/usr/bin/env groovy

node('elixir') {
  stage('Pre-build') {
    step([$class: 'WsCleanup'])

    checkout scm

    sh 'mix local.hex --force'
    sh 'mix local.rebar --force'
    sh 'mix clean'
    sh 'mix deps.get'

    stash name: 'source', useDefaultExcludes: false
  }
}

parallel (
  'Build [test]': {
    node('elixir') {
      stage('Build [test]') {
        step([$class: 'WsCleanup'])

        unstash 'source'

        withEnv (['MIX_ENV=test']) {
          sh 'mix compile'
        }

        stash 'build-test'
      }
    }
  },
  'Build [prod]': {
    node('elixir') {
      stage('Build [prod]') {
        step([$class: 'WsCleanup'])

        unstash 'source'

        withEnv (['MIX_ENV=prod']) {
          sh 'mix compile'
        }

        stash 'build-prod'
      }
    }
  }
)

parallel (
  // 'Lint': {
  //   node('elixir') {
  //     stage('Lint') {
  //       step([$class: 'WsCleanup'])

  //       unstash 'source'
  //       unstash 'build-test'

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

        unstash 'build-prod'

        // HACK: mix complains if I don't run deps.get again, not sure why
        sh "mix deps.get"

        // Reuse existing plt
        sh "cp ~/.mix/helf/*prod*.plt* _build/prod || :"

        withEnv (['MIX_ENV=prod']) {
          sh "mix dialyzer --halt-exit-status"
        }

        // Store newly generated plt
        // Do it on two commands because we want it failing if .plt is not found
        sh "cp _build/prod/*.plt ~/.mix/helf/"
        sh "cp _build/prod/*.plt.hash ~/.mix/helf/"
      }

    }
  },
  'Tests': {
    node('elixir') {
      stage('Tests') {
        step([$class: 'WsCleanup'])

        unstash 'source'
        unstash 'build-test'

        withEnv (['MIX_ENV=test']) {
          sh 'mix test'
        }
      }
    }
  }
)