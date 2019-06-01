/**
 * I own an AZERTY keyboard, you'll have to change the settings
 * right below if you have a QWERTY keyboard
 */

//press to move
int upKey = ' ';
int downKey = 'c';
int leftKey = 'q';
int rightKey = 'd';
int forwardKey = 'z';
int backwardKey = 's';
//press + scroll to change the depth of field
int focusKey = 'f';
int apertureKey = 'a';



PVector pos = new PVector(3.048768, -0.37786898, -0.6036299);
PVector dir = new PVector(-0.9444748, 0.25003102, 0.21319441).normalize();
float focalLength = 1.586674;
float focalDistance = 2.2591374;
float aperture = 0.03;

int spp;
ArrayList<Light> lights = new ArrayList<Light>();
PShader pathTracer;
boolean left, right, forward, backward, up, down;


void setup() {
  //twice as many pixels -> twice as slow, don't go crazy on the resolution
  size(720, 405, P2D);
  pathTracer = loadShader("/shaders/fragment.glsl");
  
  lights.add(new Light(new PVector(1.2, .6, 1.2), color(50, 100, 255), 7, .0));
  lights.add(new Light(new PVector(1, 1, -1), color(255, 100, 50), 7, .1));
  
  pathTracer.set("hdri", loadImage("hdri.png"));
  pathTracer.set("lightPositions", getLightPositions(), 3);
  pathTracer.set("lightColors", getLightColors(), 3);
  pathTracer.set("lightRadii", getLightRadii());
}

void draw() {
  
  move();
  spp ++;
  pathTracer.set("posCam", pos);
  pathTracer.set("dirCam", dir);
  pathTracer.set("focalLength", focalLength);
  pathTracer.set("focalDistance", focalDistance);
  pathTracer.set("aperture", aperture);
  pathTracer.set("spp", spp);
  
  filter(pathTracer);
  
  println("\n\n\n\n");
  println("pos : " + pos);
  println("dir : " + dir);
  println("focalLength : " + focalLength);
  println("focalDistance : " + focalDistance);
  println("aperture : " + aperture);
}

void reset(){
  spp = 0;
}

void move(){
  
  float speed = .05;
  
  if(forward)  pos.add(dir.copy().setMag(speed));
  if(backward) pos.sub(dir.copy().setMag(speed));
  if(left)     pos.sub(new PVector(dir.y, -dir.x, 0).setMag(speed));
  if(right)    pos.add(new PVector(dir.y, -dir.x, 0).setMag(speed));
  if(up)       pos.add(new PVector(0, 0, 1).setMag(speed));
  if(down)     pos.sub(new PVector(0, 0, 1).setMag(speed));
  
  if(forward || backward || left || right || up || down) reset();
}

void mouseDragged() {
  
  float sensitivity = 1.0 / focalLength / max(width, height);
  PVector mouvX = new PVector(-dir.y, dir.x, 0);
  PVector mouvY = dir.copy().cross(mouvX);
  mouvX.setMag((pmouseX - mouseX) * sensitivity);
  mouvY.setMag((pmouseY - mouseY) * sensitivity);
  dir.add(mouvX).add(mouvY).normalize();
  reset ();
}

void mouseWheel(MouseEvent e) {
  
  int count = e.getCount();
  
  if      (keyPressed && key == focusKey) focalDistance *= pow(.97, count);
  else if (keyPressed && key == apertureKey) aperture *= pow(.95, count);
  else focalLength *= pow(.95, count);
  reset();
}

void keyPressed() {

  if      (key == forwardKey)  forward = true;
  else if (key == backwardKey) backward = true;
  else if (key == leftKey)     left = true;
  else if (key == rightKey)    right = true;
  else if (key == upKey)       up = true;
  else if (key == downKey)     down = true;
}

void keyReleased() {

  if      (key == forwardKey)  forward = false;
  else if (key == backwardKey) backward = false;
  else if (key == leftKey)     left = false;
  else if (key == rightKey)    right = false;
  else if (key == upKey)       up = false;
  else if (key == downKey)     down = false;
}

float[] getLightPositions() {
  float[] lightPositions = new float[lights.size() * 3];
  int index = 0;
  for (Light light : lights) {
    lightPositions[index  ] = light.pos.x;
    lightPositions[index+1] = light.pos.y;
    lightPositions[index+2] = light.pos.z;
    index += 3;
  }
  return lightPositions;
}

float[] getLightColors() {
  float[] lightColors = new float[lights.size() * 3];
  int index = 0;
  for (Light light : lights) {
    lightColors[index  ] = red  (light.col) * light.intensity / 255;
    lightColors[index+1] = green(light.col) * light.intensity / 255;
    lightColors[index+2] = blue (light.col) * light.intensity / 255;
    index += 3;
  }
  return lightColors;
}

float[] getLightRadii() {
  float[] lightRadii = new float[lights.size()];
  int index = 0;
  for (Light light : lights) {
    lightRadii[index++] = light.radius;
  }
  return lightRadii;
}

class Light {
  PVector pos;
  color col;
  float intensity;
  float radius;
  
  Light(PVector pos, color col, float intensity, float radius){
    this.pos = pos;
    this.col = col;
    this.intensity = intensity;
    this.radius = radius;
  }
}
