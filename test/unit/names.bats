#!/usr/bin/env bats
# Literal `$...` strings below are intentional test data.
# shellcheck disable=SC2016
# Secret names become env var names and keychain account names, so they are
# the main input that must be validated.

load '../test_helper'

@test "accepts ENV_VAR style names" {
	for name in GITHUB_TOKEN _PRIVATE a lower_case X1 SENTRY_AUTH_TOKEN_2; do
		run call_fn valid_secret_name "$name"
		[ "$status" -eq 0 ]
	done
}

@test "rejects names that are not valid env var names" {
	for name in '' 1ABC FOO-BAR 'FOO BAR' 'FOO=BAR' 'X;rm -rf /' '$(id)' 'FOO.BAR' 'é'; do
		run call_fn valid_secret_name "$name"
		[ "$status" -ne 0 ]
	done
}

@test "rejects names with an embedded newline" {
	run call_fn valid_secret_name $'GOOD\nBAD'
	[ "$status" -ne 0 ]
}

@test "service name is namespaced under the configurable prefix" {
	run call_fn service_name_for GITHUB_TOKEN
	[ "$output" = "it.simoneandreani.dev-secret.GITHUB_TOKEN" ]

	DEV_SECRET_SERVICE_PREFIX=com.example.test run call_fn service_name_for GITHUB_TOKEN
	[ "$output" = "com.example.test.GITHUB_TOKEN" ]
}
