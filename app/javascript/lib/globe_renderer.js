// Equirectangular mask from Natural Earth 1:110m land (public domain).
// https://github.com/nvkelso/natural-earth-vector/blob/v5.1.2/geojson/ne_110m_land.geojson
const vertexShader = `
  attribute vec2 position;
  void main() {
    gl_Position = vec4(position, 0.0, 1.0);
  }
`

const fragmentShader = `
  precision mediump float;

  uniform vec2 resolution;
  uniform float azimuth;
  uniform float tilt;
  uniform float radius;
  uniform sampler2D landMask;
  const float PI = 3.14159265;

  void main() {
    vec2 point = (gl_FragCoord.xy - resolution * 0.5) / radius;
    float distanceFromCenter = length(point);
    float halo = 1.0 - smoothstep(1.0, 1.19, distanceFromCenter);

    if (distanceFromCenter >= 1.0) {
      gl_FragColor = vec4(0.10, 0.58, 0.72, halo * halo * 0.30);
      return;
    }

    vec3 normal = vec3(point, sqrt(max(0.0, 1.0 - dot(point, point))));
    // Undo the camera's latitude tilt before looking up longitude and latitude.
    float latitude = asin(clamp(normal.y * cos(tilt) + normal.z * sin(tilt), -1.0, 1.0));
    float longitude = atan(normal.x, normal.z * cos(tilt) - normal.y * sin(tilt)) + azimuth;
    vec2 uv = vec2(fract(longitude / (2.0 * PI) + 0.5), 0.5 - latitude / PI);
    float land = smoothstep(0.20, 0.75, texture2D(landMask, uv).r);

    vec2 cell = fract(uv * vec2(252.0, 126.0)) - 0.5;
    float dotPattern = 1.0 - smoothstep(0.16, 0.31, length(cell));
    vec2 grid = abs(fract(uv * vec2(24.0, 12.0) + 0.5) - 0.5);
    float gridLine = (1.0 - smoothstep(0.010, 0.024, min(grid.x, grid.y))) * normal.z;
    float lighting = 0.43 + 0.57 * max(0.0, dot(normal, normalize(vec3(-0.65, 0.52, 0.9))));
    float rim = pow(1.0 - normal.z, 3.25);

    vec3 ocean = vec3(0.032, 0.105, 0.188);
    vec3 coast = vec3(0.066, 0.31, 0.40);
    vec3 base = mix(ocean, coast, land);
    base += land * dotPattern * vec3(0.10, 0.33, 0.32);
    base += gridLine * vec3(0.026, 0.11, 0.15);

    vec3 color = base * lighting + rim * vec3(0.13, 0.51, 0.64);
    gl_FragColor = vec4(color, 1.0);
  }
`

export const GLOBE_RADIUS = 0.395

export class GlobeRenderer {
  constructor(canvas, image) {
    const gl = canvas.getContext("webgl", { alpha: true, antialias: false, premultipliedAlpha: false })
    if (!gl) throw new Error("WebGL unavailable")
    this.gl = gl
    this.canvas = canvas

    try {
      this.program = gl.createProgram()
      this.shaders = []
      for (const [type, source] of [[gl.VERTEX_SHADER, vertexShader], [gl.FRAGMENT_SHADER, fragmentShader]]) {
        const shader = gl.createShader(type)
        this.shaders.push(shader)
        gl.shaderSource(shader, source)
        gl.compileShader(shader)
        if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(shader))
        gl.attachShader(this.program, shader)
      }
      gl.linkProgram(this.program)
      if (!gl.getProgramParameter(this.program, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(this.program))
      this.shaders.forEach(shader => gl.deleteShader(shader))
      this.shaders = []
      gl.useProgram(this.program)

      this.buffer = gl.createBuffer()
      gl.bindBuffer(gl.ARRAY_BUFFER, this.buffer)
      gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW)
      const position = gl.getAttribLocation(this.program, "position")
      gl.enableVertexAttribArray(position)
      gl.vertexAttribPointer(position, 2, gl.FLOAT, false, 0, 0)

      this.texture = gl.createTexture()
      gl.bindTexture(gl.TEXTURE_2D, this.texture)
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image)
      gl.generateMipmap(gl.TEXTURE_2D)
      gl.uniform1i(gl.getUniformLocation(this.program, "landMask"), 0)

      this.uniforms = Object.fromEntries(["resolution", "radius", "azimuth", "tilt"].map(name => [
        name, gl.getUniformLocation(this.program, name)
      ]))
    } catch (error) {
      this.dispose()
      throw error
    }
  }

  resize(width, height) {
    const scale = Math.min(window.devicePixelRatio || 1, 1.5)
    this.canvas.width = Math.max(1, Math.round(width * scale))
    this.canvas.height = Math.max(1, Math.round(height * scale))
    this.gl.viewport(0, 0, this.canvas.width, this.canvas.height)
    this.gl.uniform2f(this.uniforms.resolution, this.canvas.width, this.canvas.height)
    this.gl.uniform1f(this.uniforms.radius, Math.min(this.canvas.width, this.canvas.height) * GLOBE_RADIUS)
  }

  draw(azimuth, tilt) {
    this.gl.uniform1f(this.uniforms.azimuth, azimuth)
    this.gl.uniform1f(this.uniforms.tilt, tilt)
    this.gl.drawArrays(this.gl.TRIANGLES, 0, 3)
  }

  dispose() {
    this.shaders?.forEach(shader => this.gl.deleteShader(shader))
    this.gl.deleteTexture(this.texture)
    this.gl.deleteBuffer(this.buffer)
    this.gl.deleteProgram(this.program)
  }
}
