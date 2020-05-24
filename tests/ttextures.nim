import aglet
import aglet/window/glfw
import glm/noise

type
  Vertex = object
    position: Vec2f
    textureCoords: Vec2f

var agl = initAglet()
agl.initWindow()

const
  VertexSource = """
    #version 330 core

    layout (location = 0) in vec2 position;
    layout (location = 1) in vec2 textureCoords;

    out vec2 fragTextureCoords;

    void main(void) {
      gl_Position = vec4(position, 0.0, 1.0);
      fragTextureCoords = textureCoords;
    }
  """
  FragmentSource = """
    #version 330 core

    in vec2 fragTextureCoords;

    uniform sampler1D noise;

    out vec4 color;

    void main(void) {
      float intensity = texture(noise, fragTextureCoords.x).r;
      color = vec4(intensity, 1.0, 1.0, 1.0);
    }
  """

var
  win = agl.newWindowGlfw(800, 600, "ttextures",
                          winHints(resizable = false))
  prog = win.newProgram[:Vertex](VertexSource, FragmentSource)
  rect = win.newMesh(
    primitive = dpTriangles,
    vertices = [
      Vertex(position: vec2f(-0.5,  0.5), textureCoords: vec2f(0.0, 1.0)),
      Vertex(position: vec2f( 0.5,  0.5), textureCoords: vec2f(1.0, 1.0)),
      Vertex(position: vec2f( 0.5, -0.5), textureCoords: vec2f(0.0, 0.0)),
      Vertex(position: vec2f(-0.5, -0.5), textureCoords: vec2f(1.0, 0.0)),
    ],
    indices = [0'u32, 1, 2, 2, 3, 0],
  )
  noiseMap: seq[float32]

for i in 0..<128:
  noiseMap.add((perlin(vec2f(0.0, i / 128 * 4)) + 1) / 2)

var noiseTex = win.newTexture1D(noiseMap.len, noiseMap[0].unsafeAddr)

while not win.closeRequested:
  var target = win.render()
  target.clearColor(vec4f(0.0, 0.0, 0.0, 1.0))
  target.draw(prog, rect, uniforms {
    noise: noiseTex.sampler()
  })
  target.finish()

  win.pollEvents do (event: InputEvent):
    discard