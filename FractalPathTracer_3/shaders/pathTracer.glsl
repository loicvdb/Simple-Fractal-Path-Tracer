/**
This shader is mostly based on this article by Mikael Hvidtfeldt Christensen:
http://blog.hvidtfeldts.net/index.php/2015/01/path-tracing-3d-fractals/
*/
#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

#define PROCESSING_TEXTURE_SHADER

uniform sampler2D texture;
uniform vec2 resolution;

#define Pi 3.14159265359
#define MaxSteps 500
#define Epsilon .0000002
#define Bounces 2
#define StepFactor .95
#define MaxDist 5.0
#define ShapeColor vec3(1, 1, 1)
#define Iterations 100
#define Bailout 1.2
#define Power 8.0
#define AmdFactor .05
#define DetailFactor 4.0
#define Fractal 0

uniform vec3 posCam;
uniform vec3 previousPosCam;
uniform vec3 dirCam;
uniform vec3 previousDirCam;
uniform float focalLength;
uniform float previousFocalLength;
uniform float focalDistance;
uniform float aperture;
uniform float shutter;

uniform float fractalParameters[3];

uniform int spp;
uniform sampler2D hdri;

const int maxLightAmount = 8;
uniform vec3 lightPositions[maxLightAmount];
uniform vec3 lightColors[maxLightAmount];
uniform float lightRadii[maxLightAmount];

vec2 seed;

float rand(vec2 n) {
	return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

float randomFloat(){
  seed += vec2(1.3213553, -1.1651654);
  return rand(seed);
}

float focusSize(vec3 pos){
	return aperture / focalDistance * abs((focalDistance - length(pos - posCam)));
}

float adaptiveMinDist(vec3 pos){
	float pixelSize = length(pos - posCam)/focalLength / resolution.y;
	return pixelSize/DetailFactor + focusSize(pos)*AmdFactor + Epsilon;
}

vec3 ortho(vec3 v) {
  return abs(v.x) > abs(v.z) ? vec3(-v.y, v.x, 0.0)  : vec3(0.0, -v.z, v.y);
}

vec3 getCosineWeightedSample(vec3 dir) {
	vec3 o1 = normalize(ortho(dir));
	vec3 o2 = normalize(cross(dir, o1));
	vec2 r = vec2(randomFloat(), randomFloat());
	r.x = r.x * 2.0 * Pi;
	r.y = pow(r.y, .5);
	float oneminus = sqrt(1.0-r.y*r.y);
	return cos(r.x) * oneminus * o1 + sin(r.x) * oneminus * o2 + r.y * dir;
}

vec3 getConeSample(vec3 dir, float theta) {
	vec3 o1 = normalize(ortho(dir));
	vec3 o2 = normalize(cross(dir, o1));
	vec2 r =  vec2(randomFloat(), randomFloat());
	r.x = r.x * 2.0 * Pi;
	r.y = 1.0 - r.y * theta;
	float oneminus = sqrt(1.0 - r.y*r.y);
	return cos(r.x) * oneminus * o1 + sin(r.x) * oneminus * o2 + r.y * dir;
}

#if Fractal == 0

float distanceEstimation(vec3 pos){
  vec3 z = pos;
	float dr = 1.0;
	float r = 0.0;
	for (int i = 0; i < Iterations ; i++) {
		r = length(z);
		if (r>Bailout) break;
		float theta = acos(z.z/r);
		float phi = atan(z.y,z.x);
		dr =  pow( r, Power-1.0)*Power*dr + 1.0;
		float zr = pow( r,Power);
		theta = theta*Power;
		phi = phi*Power;
		z = zr*vec3(sin(theta)*cos(phi), sin(phi)*sin(theta), cos(theta));
		z+=pos;
	}
	return 0.5*log(r)*r/dr;
}

#elif Fractal == 1

float distanceEstimation(vec3 pos){
  vec3 z = pos;
	float dr = 1.0;
	float r = 0.0;
	for (int i = 0; i < Iterations ; i++) {
		r = length(z);
		if (r>Bailout) break;
		float theta = acos(z.z/r);
		float phi = atan(z.y,z.x);
		dr =  pow( r, Power-1.0)*Power*dr + 1.0;
		float zr = pow( r,Power);
		theta = theta*Power;
		phi = phi*Power;
		z = zr*vec3(sin(theta)*cos(phi), sin(phi)*sin(theta), cos(theta));
		z += vec3(fractalParameters[0], fractalParameters[1], fractalParameters[2]);
	}
	return 0.5*log(r)*r/dr;
}

#elif Fractal == 2

float distanceEstimation(vec3 z){
		float melt = 2;
		float Scale = 2. + fractalParameters[1];
    float angle = fractalParameters[0];
    float c = cos(angle), s = sin(angle);
    mat3 rx = mat3(1, 0, 0, 0, c, -s, 0, s, c);
    mat3 ry = mat3(c, 0, -s, 0, 1, 0, s, 0, c);
    mat3 rz = mat3(c, -s, 0, s, c, 0, 0, 0, 1);
    mat3 rot = rx * ry * rz;

    float n = 0.;
    while (n < Iterations) {
       z = abs(z);
       if(z.x < z.y) z.xy = z.yx;
       if(z.x < z.z) z.xz = z.zx;
       if(z.y < z.z) z.yz = z.zy;
       z *= rot;
       z = abs(z);
       z = z*Scale - vec3(vec3((Scale-1.0)).xy, 0);
       n++;
    }
		float diam = melt / pow(1.75, n);
    return length(z) * pow(Scale, -n) - diam;
}

#endif

vec3 normalEstimation(vec3 pos){
  vec3 xDir = vec3(Epsilon, 0, 0);
  vec3 yDir = vec3(0, Epsilon, 0);
  vec3 zDir = vec3(0, 0, Epsilon);
  return normalize(
									 	vec3(	distanceEstimation(pos + xDir),
	  											distanceEstimation(pos + yDir),
  												distanceEstimation(pos + zDir))
								 		- vec3(distanceEstimation(pos))
									);
}

bool trace(inout vec3 pos, in vec3 dir, out vec3 normal){
  for(int i = 0; i < MaxSteps; i++){
    float dist = distanceEstimation(pos);
    if(dist < adaptiveMinDist(pos)) break;
    pos += dir * StepFactor * dist;
    if(length(pos-posCam) > MaxDist){
      pos = posCam + MaxDist * dir;
      return false;
    }
  }
  normal = normalEstimation(pos);
  return true;
}

vec3 background(vec3 dir){
  float x = atan(dir.x, dir.y) / (2*Pi) + .5;
  float y = -dir.z / 2 + .5;
  return texture(hdri, vec2(x, y)).rgb;
}

void bounce(inout vec3 pos, inout vec3 dir, in vec3 normal){
  dir = getCosineWeightedSample(normal);
  pos += adaptiveMinDist(pos) * normal;
}

vec3 nextEventEstimation(vec3 pos, vec3 normal){
  vec3 nee = vec3(0.0);
  for(int i = 0; i < maxLightAmount; i++){
    if(length(lightColors[i]) != 0){
      vec3 dir = normalize(lightPositions[i] - pos);
      if(dot(normal, dir) > 0){
        float dist = max(length(lightPositions[i] - pos), lightRadii[i]);
        float theta = asin(lightRadii[i] / dist);
        vec3 lightDir = getConeSample(dir, theta);
        vec3 shadowRayPos = pos;
        vec3 placeHoldernormal;
        bool hit = trace(shadowRayPos, lightDir, placeHoldernormal);
        if(!hit || dot(shadowRayPos - lightPositions[i], lightDir) > 0.0) {
          nee += lightColors[i] * dot(normal, dir) * pow(1.0/dist, 2);
        }
      }
    }
  }
  return nee;
}

vec3 rayColor(vec3 pos, vec3 dir){
  vec3 contribution = vec3(1.0);
  vec3 rayColor = vec3(0.0);
  vec3 normal;
  for(int i = 0; i <= Bounces; i++) {
    if(!trace(pos, dir, normal)){
      rayColor += contribution * background(dir);
      return rayColor;
      break;
    }
    bounce(pos, dir, normal);
    if(i < Bounces) rayColor += contribution * ShapeColor * nextEventEstimation(pos, normal);
    contribution *= ShapeColor * dot(normal, dir);
  }
  return rayColor;
}

vec3 sampleRay(){

  float interpolationFactor = randomFloat() * shutter;
	vec3 iPosCam = interpolationFactor * previousPosCam + (1-interpolationFactor) * posCam;
	vec3 iDirCam = interpolationFactor * previousDirCam + (1-interpolationFactor) * dirCam;
	float iFocalLength = interpolationFactor * previousFocalLength + (1-interpolationFactor) * focalLength;

  vec2 coords = (gl_FragCoord.xy - (resolution + vec2(randomFloat(), randomFloat()))/2.0) / resolution.y;

  vec3 camX = vec3(-iDirCam.y, iDirCam.x, 0);
	vec3 camY = cross(camX, iDirCam);
	vec3 sensorX = camX * (coords.x/length(camX));
	vec3 sensorY = camY * (coords.y/length(camY));
	vec3 centerSensor = iPosCam - iDirCam * iFocalLength;
	vec3 posOnSensor = centerSensor + sensorX + sensorY;
	vec3 posInFocus = iPosCam + (iPosCam - posOnSensor) * (focalDistance / length(iPosCam - posOnSensor));

	float angle = randomFloat() * 2*Pi - Pi;
	float radius = aperture*sqrt(randomFloat());

	float xAperture = radius * cos(angle);
	float yAperture = radius * sin(angle);

	vec3 vecAperture = camX * (xAperture / length(camX)) + camY * (yAperture / length(camY));

	vec3 pos= iPosCam + vecAperture;
	vec3 dir = normalize(posInFocus - pos);

  return rayColor(pos, dir);
}


void main() {
  seed = gl_FragCoord.xy / resolution + vec2(spp);

  vec3 previousColor = texture2D(texture, gl_FragCoord.xy / resolution).rgb * (spp-1.0);

  int samples = 1;
  vec3 newColor;
  for(int i = 0; i < samples; i++){
    newColor += sampleRay();
  }
  newColor /= samples;
	gl_FragColor = vec4((previousColor + newColor) / spp, 1.0);
}
