## 1D, 2D, and 3D textures and samplers.

import std/tables

import enums
import framebuffer
import gl
import pixeltypes
import rect
import uniform
import window


# types

type
  TexturePixelType* = ColorPixelType | DepthPixelType | DepthStencilPixelType
    ## Pixel formats supported by textures.

  TextureMinFilter* = FilteringMode
  TextureMagFilter* = range[fmNearest..fmLinear]

  TextureWrap* = enum
    ## Texture wrapping mode.
    twRepeat
    twMirroredRepeat
    twClampToEdge
    twClampToBorder

  SamplerParams = tuple
    minFilter: TextureMinFilter
    magFilter: TextureMagFilter
    wrapS, wrapT, wrapR: TextureWrap
    # std/hashes for tuples was having a stroke so I had to do this
    # instead of using a Vec4f
    borderColor: (float32, float32, float32, float32)
  Sampler* = ref object
    ## A sampler object. These are assigned to individual texture units for use
    ## in shaders.
    texture {.cursor.}: Texture
    id: GlUint
    textureTarget: TextureTarget

  Texture* = ref object of FramebufferAttachment
    ## Base texture. All other texture types inherit from this.
    window: Window
    gl: OpenGl
    id: GlUint
    samplers: Table[SamplerParams, Sampler]
    dirty: bool
    target: TextureTarget

  TextureArray = ref object of Texture

  Texture1D*[T: TexturePixelType] {.final.} = ref object of Texture
    ## 1D texture.
    fWidth: int
  Texture2D*[T: TexturePixelType] {.final.} = ref object of Texture
    ## 2D texture.
    fSize: Vec2i
    fSamples: int
  Texture3D*[T: TexturePixelType] {.final.} = ref object of Texture
    ## 3D texture.
    fSize: Vec3i
  Texture1DArray*[T: TexturePixelType] {.final.} = ref object of TextureArray
    ## An array of 1D textures.
    fWidth, fLen: int
  Texture2DArray*[T: TexturePixelType] {.final.} = ref object of TextureArray
    ## An array of 2D textures.
    fSize: Vec2i
    fLen: int
    fSamples: int
  TextureCubeMap*[T: TexturePixelType] {.final.} = ref object of Texture
    ## A cubemap texture. This stores six textures for all the individual sides
    ## of a cube. This is commonly used for skyboxes, as it only requires one
    ## texture unit while providing a total of 6 textures.
    fSize: Vec2i

  Some2DTexture* = Texture2D | Texture2DArray
    ## Texture that can be multisampled.

  ByteArray* = concept array
    ## Describes an array of values, of which each one can be casted to a uint8.
    sizeof(array[int]) == 1

  BinaryImageBuffer* = concept image
    ## Concept describing an image that holds some arbitrary 8-bit data.
    image.width is SomeInteger
    image.height is SomeInteger
    image.data is ByteArray


# utilities

const
  fmMipmapped = {fmNearestMipmapNearest..fmLinearMipmapLinear}

proc toGlEnum(filter: FilteringMode): GlEnum =
  case filter
  of fmNearest: GL_NEAREST
  of fmLinear: GL_LINEAR
  of fmNearestMipmapNearest: GL_NEAREST_MIPMAP_NEAREST
  of fmNearestMipmapLinear: GL_NEAREST_MIPMAP_LINEAR
  of fmLinearMipmapNearest: GL_LINEAR_MIPMAP_NEAREST
  of fmLinearMipmapLinear: GL_LINEAR_MIPMAP_LINEAR

proc toGlEnum(wrap: TextureWrap): GlEnum =
  case wrap
  of twRepeat: GL_REPEAT
  of twMirroredRepeat: GL_MIRRORED_REPEAT
  of twClampToEdge: GL_CLAMP_TO_EDGE
  of twClampToBorder: GL_CLAMP_TO_BORDER

proc format(T: type[TexturePixelType]): GlEnum =
  when T is Red8 | Red16 | Red32 | Red32f: GL_RED
  elif T is Rg8 | Rg16 | Rg32 | Rg32f: GL_RG
  elif T is Rgb8 | Rgb16 | Rgb32 | Rgb32f: GL_RGB
  elif T is Rgba8 | Rgba16 | Rgba32 | Rgba32f: GL_RGBA
  elif T is Depth16 | Depth24 | Depth32: GL_DEPTH_COMPONENT

proc dataType(T: type[AnyPixelType]): GlEnum =
  when T is Red8 | Rg8 | Rgb8 | Rgba8 | Depth24: GL_TUNSIGNED_BYTE
  elif T is Red16 | Rg16 | Rgb16 | Rgba16 |
            Depth16: GL_TUNSIGNED_SHORT
  elif T is Red32 | Rg32 | Rgb32 | Rgba32: GL_TUNSIGNED_INT
  elif T is Red32f | Rg32f | Rgb32f | Rgba32f | Depth32f: GL_TFLOAT


# getters

proc texture*(sampler: Sampler): Texture =
  ## Retrieves the texture this sampler was created for.
  ## Note that this returns the *generic* ``Texture`` type, which can later be
  ## casted to any of its descendants. The type of the descendant can be checked
  ## using the ``of`` operator, eg. ``sampler.texture of Texture2D`` will check
  ## if the sampler was created for a 2D texture.
  sampler.texture

proc width*(texture: Texture1D): int =
  ## Returns the width of the texture.
  texture.fWidth

proc width*(array: Texture1DArray): int =
  ## Returns the width of all the 1D textures stored in the array.
  array.fWidth

proc len*(array: Texture1DArray): int =
  ## Returns how many 1D textures the array stores.
  array.fLen

proc size*(texture: Texture2D): Vec2i =
  ## Returns the size of the texture as a vector.
  texture.fSize

proc width*(texture: Texture2D): int =
  ## Returns the width of the texture.
  texture.size.x

proc height*(texture: Texture2D): int =
  ## Returns the height of the texture.
  texture.size.y

proc size*(array: Texture2DArray): Vec2i =
  ## Returns the size of the array's textures as a vector.
  array.fSize

proc width*(array: Texture2DArray): int =
  ## Returns the width of all the 2D textures stored in the array.
  array.size.x

proc height*(array: Texture2DArray): int =
  ## Returns the height of all the 2D textures stored in the array.
  array.size.y

proc len*(array: Texture2DArray): int =
  ## Returns how many 2D textures the array stores.
  array.fLen

proc multisampled*(texture: Some2DTexture): bool =
  ## Returns whether the texture is multisampled.
  texture.fSamples > 0

proc samples*(texture: Some2DTexture): int =
  ## Returns the amount of samples in a multisampled texture.
  ## Returns 0 if the texture is not multisampled.
  texture.fSamples

proc size*(texture: Texture3D): Vec3i =
  ## Returns the size of the texture as a vector.
  texture.fSize

proc width*(texture: Texture3D): int =
  ## Returns the width of the texture.
  texture.size.x

proc height*(texture: Texture3D): int =
  ## Returns the height of the texture.
  texture.size.y

proc depth*(texture: Texture3D): int =
  ## Returns the depth of the texture.
  texture.size.z

proc size*(texture: TextureCubeMap): Vec2i =
  ## Returns the size of the cubemap's textures as a vector.
  texture.fSize

proc width*(texture: TextureCubeMap): int =
  ## Returns the width of each texture in the cubemap.
  texture.size.x

proc height*(texture: TextureCubeMap): int =
  ## Returns the height of each texture in the cubemap.
  texture.size.y

proc use[T: Texture](texture: T) =
  texture.window.IMPL_makeCurrent()
  texture.gl.bindTexture(texture.target, texture.id)


# 1D

proc allocate*[T: TexturePixelType](texture: Texture1D[T], width: Positive) =
  ## Allocates a data store for the given texture.
  ## What the data store contains after allocation is undefined.
  ## This procedure is meant primarily for allocating framebuffer attachments.
  ## Prefer ``upload`` if you need to upload data.

  texture.use()
  texture.gl.data1D(width, T.internalFormat, T.format, T.dataType)
  texture.fWidth = width

proc subImage*[T: ColorPixelType](texture: Texture1D[T],
                                  x: int, width: Positive,
                                  data: ptr T) =
  ## Updates a portion of the texture. ``x + width`` must be less than or equal
  ## to ``texture.width``, otherwise an assertion is triggered.
  ## This procedure deals with pointers and so it is **unsafe**, prefer the
  ## ``openArray`` version instead.

  assert x >= 0
  assert x + width <= texture.width, "pixels cannot be copied out of bounds"
  assert data != nil
  texture.use()
  texture.gl.subImage1D(x, width, T.format, T.dataType, data)
  texture.dirty = true

proc subImage*[T: ColorPixelType](texture: Texture1D[T], x: int,
                                  data: openArray[T]) =
  ## Safe version of ``subImage``. The width is inferred from the length of
  ## ``data``.

  texture.subImage[:T](x, data.len, data[0].unsafeAddr)

proc upload*[T: ColorPixelType](texture: Texture1D[T],
                                width: int, data: ptr T) =
  ## Upload generic data to the texture. This will only allocate a new data
  ## store if the texture's existing width does not match the target width.
  ## This procedure is **unsafe** and should only be used in specific cases.
  ## Prefer the ``openArray`` version instead.

  assert data != nil
  assert width > 0
  texture.use()
  if texture.width != width:
    texture.gl.data1D(width, T.internalFormat, T.format, T.dataType)
    texture.fWidth = width
  texture.subImage(0, width, data)

proc upload*[T: ColorPixelType](texture: Texture1D[T], data: openArray[T]) =
  ## Safe version of ``upload``. The width of the texture is inferred from the
  ## length of the data array. This will only allocate a new data store if the
  ## texture's existing width does not match the target width.

  assert data.len > 0
  texture.upload(data.len, data[0].unsafeAddr)

template textureInit(gl: OpenGl) =
  # bind createTexture, deleteTexture

  new(result) do (texture: typeof(result)):
    IMPL_makeCurrent(texture.window)
    deleteTexture(texture.gl, texture.id)
  result.window = window
  result.id = createTexture(gl)
  result.gl = gl

proc newTexture1D*[T: TexturePixelType](window: Window): Texture1D[T] =
  ## Creates a new 1D texture. The texture does not contain any data; a data
  ## store must be allocated using ``upload`` before the texture is used.

  window.IMPL_makeCurrent()
  var gl = window.IMPL_getGlContext()
  textureInit(gl)
  result.target = ttTexture1D

proc newTexture1D*[T: ColorPixelType](window: Window, width: Positive,
                                      data: ptr T): Texture1D[T] =
  ## Creates a new 1D texture and initializes it with data stored at the
  ## given pointer. This procedure is **unsafe** as it deals with pointers.
  ## Prefer the ``openArray`` version instead.

  result = window.newTexture1D[:T]()
  result.upload[:T](width, data)

proc newTexture1D*[T: ColorPixelType](window: Window,
                                      data: openArray[T]): Texture1D[T] =
  ## Creates a new 1D texture and initializes it with the given data.
  ## The width of the texture is inferred from the data's length, which must not
  ## be zero.

  result = window.newTexture1D[:T]()
  result.upload[:T](data)

proc newTexture1D*[T: TexturePixelType](window: Window,
                                        width: Positive): Texture1D[T] =
  ## Creates a new 1D texture and allocates a data store of the given width.
  ## What the data store contains is undefined. This procedure is primarily
  ## meant for usage with framebuffers, prefer the versions that accept
  ## ``data``.

  result = window.newTexture1D[:T]()
  result.allocate[:T](width)


# 2D

proc allocate*[T: TexturePixelType](texture: Texture2D[T], size: Vec2i,
                                    samples = 0.Natural) =
  ## Allocates a data store for the given texture. If ``samples`` is not 0, the
  ## texture will be multisampled.
  ## What the data store contains after allocation is undefined.
  ## This procedure is meant primarily for allocating framebuffer attachments.
  ## Prefer ``upload`` if you need to upload data.

  texture.use()
  if samples > 0:
    texture.gl.data2DMS(size.x, size.y, T.internalFormat, samples, true)
  else:
    texture.gl.data2D(texture.target, size.x, size.y,
                      T.internalFormat, T.format, T.dataType)
  texture.fSize = size
  texture.fSamples = samples

proc subImage*[T: ColorPixelType](texture: Texture2D[T], position, size: Vec2i,
                                  data: ptr T) =
  ## ``subImage`` for 2D textures. Same rules as apply as for 1D textures,
  ## except the Y coordinate is checked as well.
  ## This procedure deals with pointers and so, it is **unsafe**. Prefer the
  ## ``openArray`` version for dealing with generated data, or the
  ## ``BinaryImageBuffer`` version for dealing with data loaded from other
  ## libraries like nimPNG or flippy.

  assert position.x >= 0 and position.y >= 0
  assert size.x > 0 and size.y > 0
  assert position.x + size.x <= texture.width and
         position.y + size.y <= texture.height,
    "pixels cannot be copied out of bounds"
  assert data != nil
  texture.use()
  texture.gl.subImage2D(texture.target, position.x, position.y, size.x, size.y,
                        T.format, T.dataType, data)
  texture.dirty = true

proc subImage*[T: ColorPixelType](texture: Texture2D[T], position, size: Vec2i,
                                  data: openArray[T]) =
  ## ``subImage`` for 2D textures that accepts an ``openArray`` for data.
  ## ``data.len`` must be equal to ``size.x * size.y``, otherwise an assertion
  ## is triggered.

  assert data.len == size.x * size.y
  texture.subImage(position, size, data[0].unsafeAddr)

proc subImage*[T: ColorPixelType,
               I: BinaryImageBuffer](texture: Texture2D[T],
                                     position: Vec2i,
                                     image: I) =
  ## ``subImage`` for loading arbitrary image data to the texture.
  ## This procedure allows for compatibility with existing image libraries,
  ## like nimPNG or Flippy, without them being a hard dependency.

  assert image.data.len == image.width * image.height * T.channels
  assert position.x >= 0 and position.y >= 0
  texture.use()
  texture.gl.subImage2D(texture.target,
                        position.x, position.y, image.width, image.height,
                        T.format, T.dataType,
                        image.data[0].unsafeAddr)
  texture.dirty = true

proc upload*[T: ColorPixelType](texture: Texture2D[T],
                                size: Vec2i, data: ptr T) =
  ## Uploads arbitrary data to the texture. This only allocates a new data store
  ## if the texture's existing size does not match the target size.
  ## This procedure deals with pointers, and so it is **unsafe**. Prefer the
  ## ``openArray`` and ``BinaryImageBuffer`` versions instead.

  assert data != nil
  assert size.x > 0 and size.y > 0
  texture.use()
  if texture.width != size.x or texture.height != size.y:
    texture.gl.data2D(texture.target, size.x, size.y,
                      T.internalFormat, T.format, T.dataType)
    texture.fSize = size
  texture.subImage(vec2i(0, 0), size, data)

proc upload*[T: ColorPixelType](texture: Texture2D[T], size: Vec2i,
                                data: openArray[T]) =
  ## Safe version of ``upload``. ``data.len`` must be equal to
  ## ``size.x * size.y``, otherwise an assertion is triggered.

  texture.upload(size, data[0].unsafeAddr)

proc upload*[T: ColorPixelType,
             I: BinaryImageBuffer](texture: Texture2D[T], image: I) =
  ## Generic image buffer version of ``upload``, for use with libraries like
  ## nimPNG or Flippy.

  assert image.width > 0 and image.height > 0
  texture.use()
  if texture.width != image.width or texture.height != image.height:
    texture.gl.data2D(texture.target, image.width, image.height,
                      T.internalFormat, T.format, GL_TUNSIGNED_BYTE)
    texture.fSize = vec2i(image.width.int32, image.height.int32)
  texture.subImage(vec2i(0, 0), image)

proc newTexture2D*[T: ColorPixelType](window: Window): Texture2D[T] =
  ## Creates a new 2D texture. The texture does not contain any data; a data
  ## store must be allocated using ``upload`` before the texture is used.

  window.IMPL_makeCurrent()
  var gl = window.IMPL_getGlContext()
  textureInit(gl)
  result.target = ttTexture2D

proc newTexture2D*[T: ColorPixelType](window: Window, size: Vec2i,
                                      data: ptr T): Texture2D[T] =
  ## Creates a new 2D texture and initializes it with data stored at the given
  ## pointer. This procedure is **unsafe** as it deals with pointers.
  ## Prefer the ``openArray`` and ``BinaryImageBuffer`` versions when possible.

  result = window.newTexture2D[:T]()
  result.upload[:T](size, data)

proc newTexture2D*[T: ColorPixelType](window: Window, size: Vec2i,
                                      data: openArray[T]): Texture2D[T] =
  ## Creates a new 2D texture and initializes it with data stored in the given
  ## array.

  result = window.newTexture2D[:T]()
  result.upload[:T](size, data)

proc newTexture2D*[I: BinaryImageBuffer](window: Window,
                                         T: type[ColorPixelType],
                                         image: I): Texture2D[T] =
  ## Creates a new 2D texture and initializes it with pixels stored in the given
  ## image.

  result = window.newTexture2D[:T]()
  result.upload[:T, I](image)

proc newTexture2D*[T: TexturePixelType](window: Window,
                                        size: Vec2i,
                                        samples = 0.Natural): Texture2D[T] =
  ## Creates a new 2D texture and allocates a data store of the given size.
  ## If ``samples`` is greater than zero, the resulting texture will be
  ## multisampled. What the data store contains is undefined. This procedure is
  ## primarily meant for usage with framebuffers, prefer the versions
  ## that accept ``data``.

  result = window.newTexture2D[:T]()
  result.allocate[:T](size, samples)
  if samples > 0:
    result.target = ttTexture2DMultisample


# 3D

proc allocate*[T: TexturePixelType](texture: Texture3D[T], size: Vec3i) =
  ## Allocates a data store for the given texture.
  ## What the data store contains after allocation is undefined.
  ## This procedure is meant primarily for allocating framebuffer attachments.
  ## Prefer ``upload`` if you need to upload data.

  texture.use()
  texture.gl.data3D(texture.target, size.x, size.y, size.z,
                    T.internalFormat, T.format, T.dataType)
  texture.fSize = size

proc subImage*[T: ColorPixelType](texture: Texture3D[T], position, size: Vec3i,
                                  data: ptr T) =
  ## ``subImage`` for 3D texture.
  ## This procedure deals with pointers and so, it is **unsafe**. Prefer the
  ## ``openArray`` version instead.

  assert position.x >= 0 and position.y >= 0 and position.z >= 0
  assert size.x > 0 and size.y > 0 and size.z > 0
  assert position.x + size.x <= texture.width and
         position.y + size.y <= texture.height and
         position.z + size.z <= texture.depth,
    "pixels cannot be copied out of bounds"
  assert data != nil
  texture.use()
  texture.gl.subImage3D(texture.target,
                        position.x, position.y, position.z,
                        size.x, size.y, size.z,
                        T.format, T.dataType, data)
  texture.dirty = true

proc subImage*[T: ColorPixelType](texture: Texture3D[T], position, size: Vec3i,
                                  data: openArray[T]) =
  ## ``subImage`` for 3D textures that accepts an ``openArray`` for data.
  ## ``data.len`` must be equal to ``size.x * size.y * size.z``, otherwise an
  ## assertion is triggered.

  assert data.len == size.x * size.y * size.z
  texture.subImage(position, size, data[0].unsafeAddr)

proc upload*[T: ColorPixelType](texture: Texture3D[T],
                                size: Vec3i, data: ptr T) =
  ## Uploads arbitrary data to the texture. This only allocates a new data store
  ## if the texture's existing size does not match the target size.
  ## This procedure deals with pointers, and so it is **unsafe**. Prefer the
  ## ``openArray`` version instead.

  assert data != nil
  assert size.x > 0 and size.y > 0 and size.z > 0
  texture.use()
  if texture.width != size.x or
     texture.height != size.y or
     texture.depth != size.z:
    texture.gl.data3D(texture.target, size.x, size.y, size.z,
                      T.internalFormat, T.format, T.dataType)
    texture.fSize = size
  texture.subImage(vec3i(0, 0, 0), size, data)

proc upload*[T: ColorPixelType](texture: Texture3D[T], size: Vec3i,
                                data: openArray[T]) =
  ## Safe version of ``upload``. ``data.len`` must be equal to
  ## ``size.x * size.y * size.z``, otherwise an assertion is triggered.

  assert data.len == size.x * size.y * size.z
  texture.upload(size, data[0].unsafeAddr)

proc newTexture3D*[T: ColorPixelType](window: Window): Texture3D[T] =
  ## Creates a new 3D texture without any data. A data store must be allocated
  ## using ``upload`` before the texture is used.


  window.IMPL_makeCurrent()
  var gl = window.IMPL_getGlContext()
  textureInit(gl)
  result.target = ttTexture3D

proc newTexture3D*[T: ColorPixelType](window: Window, size: Vec3i,
                                      data: ptr T): Texture3D[T] =
  ## Creates a new 3D texture and initializes it with data stored at the given
  ## pointer. This procedure is **unsafe** as it deals with pointers.
  ## Prefer the ``openArray`` version instead.

  result = window.newTexture3D[:T]()
  result.upload[:T](size, data)

proc newTexture3D*[T: ColorPixelType](window: Window, size: Vec3i,
                                      data: openArray[T]): Texture3D[T] =
  ## Creates a new 3D texture and initializes it with data stored in the given
  ## array. ``data.len`` must be equal to ``size.x * size.y * size.z``,
  ## otherwise an assertion is triggered.

  result = window.newTexture3D[:T]()
  result.upload[:T](size, data)

proc newTexture3D*[T: TexturePixelType](window: Window,
                                        size: Vec3i): Texture3D[T] =
  ## Creates a new 3D texture and allocates a data store of the given size.
  ## What the data store contains is undefined. This procedure is primarily
  ## meant for usage with framebuffers, prefer the versions that accept
  ## ``data``.

  result = window.newTexture3D[:T]()
  result.allocate[:T](size)


# sampler

proc sampler*[T: Texture](texture: T,
                          minFilter: TextureMinFilter = fmNearestMipmapLinear,
                          magFilter: TextureMagFilter = fmLinear,
                          wrapS, wrapT, wrapR = twRepeat,
                          borderColor = rgba(0.0, 0.0, 0.0, 0.0)): Sampler =
  ## Creates a sampler for the given texture, with the provided parameters.
  ## ``minFilter`` and ``magFilter`` specify the filtering used when sampling
  ## non-integer coordinates. ``wrap(S|T|R)`` specify the texture wrapping on
  ## the X, Y, and Z axes respectively. ``borderColor`` specifies the border
  ## color to be used when any of the ``wrap`` options is ``twClampToBorder``.

  let
    borderColor = borderColor.Vec4f
    params = SamplerParams (minFilter, magFilter,
                            wrapS, wrapT, wrapR,
                            (borderColor.r, borderColor.g, borderColor.b,
                             borderColor.a))

  if params in texture.samplers:
    result = texture.samplers[params]
  else:

    result = Sampler(texture: texture,
                     id: texture.gl.createSampler(),
                     textureTarget: texture.target)

    var borderColor = borderColor
    texture.window.IMPL_makeCurrent()
    texture.gl.samplerParam(result.id, GL_TEXTURE_MIN_FILTER,
                            GlInt(minFilter.toGlEnum))
    texture.gl.samplerParam(result.id, GL_TEXTURE_MAG_FILTER,
                            GlInt(magFilter.toGlEnum))
    texture.gl.samplerParam(result.id, GL_TEXTURE_WRAP_S,
                            GlInt(wrapS.toGlEnum))
    texture.gl.samplerParam(result.id, GL_TEXTURE_WRAP_T,
                            GlInt(wrapT.toGlEnum))
    texture.gl.samplerParam(result.id, GL_TEXTURE_WRAP_R,
                            GlInt(wrapR.toGlEnum))
    texture.gl.samplerParam(result.id, GL_TEXTURE_BORDER_COLOR,
                            borderColor.caddr)

    texture.samplers[params] = result

  if minFilter in fmMipmapped and texture.dirty:
    texture.use()
    texture.gl.genMipmaps(texture.target)
    texture.dirty = false

proc toUniform*(sampler: Sampler): Uniform =
  ## Conversion proc that allows samplers to be used as uniforms.

  let usampler = USampler(textureTarget: sampler.textureTarget.uint8,
                          textureId: sampler.texture.id,
                          samplerId: sampler.id)
  result = Uniform(ty: utUSampler, valUSampler: usampler)


# framebuffer support

proc implSource(texture: Texture2D[ColorPixelType]): FramebufferSource =

  result.attachment = texture.FramebufferAttachment
  result.size = texture.size
  result.samples = texture.samples

  result.attachToFramebuffer = proc (framebuffer: GlUint, attachment: GlEnum) =
    texture.gl.attachTexture2D(attachment, texture.target,
                               texture.id, mipLevel = 0)

converter source*(texture: Texture2D[ColorPixelType]): ColorSource =
  ## ``ColorSource`` implementation for 2D textures.
  result = texture.implSource().ColorSource

converter source*(texture: Texture2D[DepthPixelType]): DepthSource =
  ## ``DepthSource`` implementation for 2D textures.
  result = texture.implSource().DepthSource

proc toFramebuffer*(texture: Texture2D): SimpleFramebuffer =
  ## Helper for easy framebuffer creation. This does not allow you to
  ## attach depth and stencil buffers; for that, use
  ## ``framebuffer.newFramebuffer``.
  result = texture.window.newFramebuffer(texture.source)

proc sampler*(simplefb: SimpleFramebuffer,
              minFilter, magFilter: TextureMagFilter = fmLinear,
              wrapS, wrapT, wrapR = twRepeat,
              borderColor = rgba(0.0, 0.0, 0.0, 0.0)): Sampler =
  ## Helper for easy *color texture* framebuffer sampling. Raises an assertion
  ## if the framebuffer does not have a texture as its color attachment.
  ## ``minFilter`` is intentionally a ``TextureMagFilter`` because right now
  ## framebuffers don't support mipmapping.

  assert simplefb.color of Texture,
    "framebuffer's color attachment must be a texture for sampling"

  let texture = simplefb.color.Texture
  result = texture.sampler(minFilter, magFilter,
                           wrapS, wrapT, wrapR,
                           borderColor)
