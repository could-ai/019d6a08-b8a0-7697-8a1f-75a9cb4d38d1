import 'dart:math';

class Vec2 {
  double x;
  double y;

  Vec2(this.x, this.y);

  Vec2.zero() : x = 0, y = 0;

  Vec2 clone() => Vec2(x, y);

  void add(Vec2 other) {
    x += other.x;
    y += other.y;
  }

  void sub(Vec2 other) {
    x -= other.x;
    y -= other.y;
  }

  void scale(double factor) {
    x *= factor;
    y *= factor;
  }

  double length() => sqrt(x * x + y * y);
  
  double lengthSquared() => x * x + y * y;

  double distanceTo(Vec2 other) {
    double dx = x - other.x;
    double dy = y - other.y;
    return sqrt(dx * dx + dy * dy);
  }

  void normalize() {
    double len = length();
    if (len > 0) {
      x /= len;
      y /= len;
    }
  }

  static Vec2 addVec(Vec2 a, Vec2 b) => Vec2(a.x + b.x, a.y + b.y);
  static Vec2 subVec(Vec2 a, Vec2 b) => Vec2(a.x - b.x, a.y - b.y);
  static Vec2 scaleVec(Vec2 a, double factor) => Vec2(a.x * factor, a.y * factor);
}
