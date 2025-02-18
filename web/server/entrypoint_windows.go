//go:build windows

package server

import (
	"go.viam.com/rdk/gostream"
	"go.viam.com/rdk/gostream/codec/x264"
)

func makeStreamConfig() gostream.StreamConfig {
	// TODO(RSDK-1771): support video on windows
	return gostream.StreamConfig{VideoEncoderFactory: x264.NewEncoderFactory()}
}
