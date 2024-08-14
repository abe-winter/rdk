// Package main provides a server offering gRPC/REST/GUI APIs to control and monitor
// a robot.
package main

import (
	"go.viam.com/utils"

	// registers all components.
	"go.viam.com/rdk/logging"
	// registers all services.
	"go.viam.com/rdk/web/server"
)

var logger = logging.NewDebugLogger("entrypoint")

func main() {
	utils.ContextualMain(server.RunServer, logger)
}
