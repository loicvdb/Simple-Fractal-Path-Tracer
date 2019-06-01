uniform mat4 transform;
attribute vec4 position;

void main() {
  gl_Position = transform * position;
}
