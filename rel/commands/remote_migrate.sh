#!/bin/bash

release_remote_ctl rpc "Mine.ReleaseTasks.ensure_database_created"
release_remote_ctl rpc "Mine.ReleaseTasks.run_migrations"
