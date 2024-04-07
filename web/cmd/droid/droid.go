// Package droid is the entrypoint for gomobile.
package droid

import (
	"os"

	"go.viam.com/utils"

	// registers all components.
	_ "go.viam.com/rdk/components/register"
	"go.viam.com/rdk/logging"
	// registers all services.
	_ "go.viam.com/rdk/services/register"
	"go.viam.com/rdk/web/server"
)

var logger = logging.NewDebugLogger("robot_server")

// DroidStopHook used by android harness to stop the RDK.
func DroidStopHook() { //nolint:revive
	server.ForceRestart = true
}

// MainEntry is called by our android app to start the RDK.
func MainEntry(configPath, writeablePath string) {
	os.Args = append(os.Args, "-config", configPath)
	utils.ContextualMain(server.RunServer, logger)
}
