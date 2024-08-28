package utils

type Vector struct {
	X, Y, Z float64
}

type Point struct {
	lat float64
	lng float64
}

func NewPoint(lat, lng float64) *Point { return &Point{lat, lng} }

func (p Point) Lat() float64 { return p.lat }
func (p Point) Lng() float64 { return p.lng }
