package config

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"go.viam.com/test"
)

func TestSyntheticModule(t *testing.T) {
	tmp := t.TempDir()
	modNeedsSynthetic := Module{
		Type:       ModuleTypeLocal,
		RawExePath: filepath.Join(tmp, "whatever.tgz"),
	}
	modNotTar := Module{
		Type:       ModuleTypeLocal,
		RawExePath: "/home/user/whatever.sh",
	}
	modNotLocal := Module{
		Type: ModuleTypeRegistry,
	}

	t.Run("NeedsSyntheticPackage", func(t *testing.T) {
		test.That(t, modNeedsSynthetic.IsLocalTarball(), test.ShouldBeTrue)
		test.That(t, modNotTar.IsLocalTarball(), test.ShouldBeFalse)
		test.That(t, modNotLocal.IsLocalTarball(), test.ShouldBeFalse)
	})

	t.Run("PackagePathDets", func(t *testing.T) {
		ppd := modNeedsSynthetic.PackagePathDets()
		test.That(t, ppd.Type, test.ShouldEqual, PackageTypeModule)
	})

	t.Run("EvaluateExePath", func(t *testing.T) {
		meta := EntrypointOnlyMetaJSON{
			Entrypoint: "entry",
		}
		testWriteJSON(t, filepath.Join(tmp, "meta.json"), &meta)
		syntheticPath, err := modNeedsSynthetic.EvaluateExePath()
		test.That(t, err, test.ShouldBeNil)
		test.That(t, syntheticPath, test.ShouldEqual,
			filepath.Join(modNeedsSynthetic.PackagePathDets().LocalDataDirectory(viamPackagesDir), meta.Entrypoint),
		)
		notTarPath, err := modNotTar.EvaluateExePath()
		test.That(t, err, test.ShouldBeNil)
		test.That(t, notTarPath, test.ShouldEqual, modNotTar.RawExePath)
	})
}

func testWriteJSON(t *testing.T, path string, value any) {
	t.Helper()
	file, err := os.Create(path)
	test.That(t, err, test.ShouldBeNil)
	defer file.Close()
	encoder := json.NewEncoder(file)
	err = encoder.Encode(value)
	test.That(t, err, test.ShouldBeNil)
}
