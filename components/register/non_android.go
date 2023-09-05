//go:build !android
package register

import (
	_ "go.viam.com/rdk/components/audioinput/register"
	_ "go.viam.com/rdk/components/camera/register"
)
