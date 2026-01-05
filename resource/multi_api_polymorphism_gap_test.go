package resource_test

import (
	"context"
	"testing"

	"go.viam.com/test"

	"go.viam.com/rdk/components/sensor"
	"go.viam.com/rdk/examples/customresources/apis/gizmoapi"
	"go.viam.com/rdk/logging"
	"go.viam.com/rdk/resource"
)

// TestPolymorphismGap_ResourceNotFoundViaSecondaryAPI demonstrates the
// core limitation preventing polymorphic resources.
//
// This test FAILS, proving that resources cannot currently be discovered
// via multiple APIs. To make it PASS, you would implement:
//
// 1. resource.Name with APIs []API field (instead of single API)
// 2. Graph indexing under all APIs during AddNode
// 3. Config support for specifying multiple APIs
//
// Run with: go test -v -run TestPolymorphismGap
func TestPolymorphismGap_ResourceNotFoundViaSecondaryAPI(t *testing.T) {
	logger := logging.NewTestLogger(t)

	// Create a resource implementing BOTH sensor.Sensor AND gizmoapi.Gizmo
	multiResource := &multiAPIResource{
		name:          "multi-sensor-gizmo",
		sensorReading: 42.0,
		gizmoArgCache: "",
	}
	const resourceName = "multi-sensor-gizmo"

	// Create resource graph
	graph := resource.NewGraph(logger)

	// Add resource to graph under sensor.API
	sensorName := sensor.Named(resourceName)
	node := resource.NewConfiguredGraphNode(
		resource.Config{
			API:  sensor.API, // ← Only ONE API can be specified
			Name: resourceName,
		},
		multiResource,
		resource.DefaultModelFamily.WithModel("fake"),
	)
	graph.AddNode(sensorName, node)

	// ========== Lookup via sensor.API: WORKS ==========
	foundNode, err := graph.FindBySimpleNameAndAPI(resourceName, sensor.API)
	test.That(t, err, test.ShouldBeNil)
	test.That(t, foundNode, test.ShouldNotBeNil)

	res, _ := foundNode.Resource()
	test.That(t, res, test.ShouldEqual, multiResource)
	t.Log("✓ Found via sensor.API (the registered API)")

	// ========== Lookup via gizmoapi.API: FAILS ==========
	// The resource DOES implement gizmoapi.Gizmo interface
	// But the graph doesn't know about this because it only indexed under sensor.API
	foundNode, err = graph.FindBySimpleNameAndAPI(resourceName, gizmoapi.API)

	// THIS ASSERTION FAILS!
	// Returns: NodeNotFoundError{Name:"multi-sensor-gizmo", API:gizmoapi.API}
	test.That(t, err, test.ShouldBeNil) // ← FAILS HERE

	if err != nil {
		t.Logf("✗ NOT found via gizmoapi.API: %v", err)
		t.Logf("")
		t.Logf("This is the polymorphism gap:")
		t.Logf("  - Resource implements both sensor.Sensor and gizmoapi.Gizmo")
		t.Logf("  - Resource is only indexed in graph under sensor.API")
		t.Logf("  - Lookup by gizmoapi.API fails even though resource supports it")
		t.Logf("")
		t.Logf("To fix, resource graph needs to index under ALL implemented APIs")
		t.FailNow()
	}

	test.That(t, foundNode, test.ShouldNotBeNil)
	res, _ = foundNode.Resource()
	test.That(t, res, test.ShouldEqual, multiResource)
}

// multiAPIResource implements BOTH sensor.Sensor and gizmoapi.Gizmo
// demonstrating polymorphism across protobuf APIs
type multiAPIResource struct {
	resource.Named
	resource.TriviallyReconfigurable
	resource.TriviallyCloseable

	name          string
	callCount     int // Shared state to prove same instance
	sensorReading float64
	gizmoArgCache string
}

// Sensor interface implementation (resource.Sensor)
func (m *multiAPIResource) Readings(ctx context.Context, extra map[string]interface{}) (map[string]interface{}, error) {
	m.callCount++
	return map[string]interface{}{
		"value": m.sensorReading,
	}, nil
}

// Gizmo interface implementation
func (m *multiAPIResource) DoOne(ctx context.Context, arg1 string) (bool, error) {
	m.callCount++
	m.gizmoArgCache = arg1
	return true, nil
}

func (m *multiAPIResource) DoOneClientStream(ctx context.Context, arg1 []string) (bool, error) {
	m.callCount++
	return true, nil
}

func (m *multiAPIResource) DoOneServerStream(ctx context.Context, arg1 string) ([]bool, error) {
	m.callCount++
	return []bool{true}, nil
}

func (m *multiAPIResource) DoOneBiDiStream(ctx context.Context, arg1 []string) ([]bool, error) {
	m.callCount++
	return []bool{true}, nil
}

func (m *multiAPIResource) DoTwo(ctx context.Context, arg1 bool) (string, error) {
	m.callCount++
	return "result", nil
}

func (m *multiAPIResource) DoCommand(ctx context.Context, cmd map[string]interface{}) (map[string]interface{}, error) {
	m.callCount++
	return nil, nil
}

func (m *multiAPIResource) Name() resource.Name {
	return resource.NewName(sensor.API, m.name)
}
