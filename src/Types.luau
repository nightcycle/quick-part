--!strict
--!native
export type PartHandle = {
	Id: number,
	Size: Vector3,
	CFrame: CFrame,
	PivotOffset: CFrame,
	Color: Color3,
	Transparency: number,
}
export type ModelHandle = { Id: number, Scale: number, WorldPivot: CFrame }
export type Shape = "Block" | "Ball" | "Cylinder" | "Wedge" | "CornerWedge"
export type PartOptions = {
	Size: Vector3,
	CFrame: CFrame?,
	PivotOffset: CFrame?,
	Color: Color3?,
	Transparency: number?,
	Material: Enum.Material?,
	MaterialVariant: string?,
	Reflectance: number?,
	CastShadow: boolean?,
	SurfaceAppearance: SurfaceAppearance?,
	Shape: Shape?,
	Geometry: Geometry?,
	TextureID: string?,
	DoubleSided: boolean?,
}
export type Face = {
	Vertices: { number },
	UVs: { Vector2 },
	Normals: { Vector3 }?,
	Colors: { Color3 }?,
	Alphas: { number }?,
}
export type Geometry = { Vertices: { Vector3 }, Faces: { Face }, TriangleCount: number }
export type GeometryInfo = {
	EditableMesh: EditableMesh,
	RenderingPart: MeshPart?,
	VertexIds: { number },
	TriangleIds: { number },
	FaceIds: { number },
	ColorId: number,
	ColorIds: { number },
	NormalIds: { number },
}
export type Stats = {
	Parts: number,
	Models: number,
	Meshes: number,
	Triangles: number,
	TriangleLimit: number,
	BatchMeshes: number,
}
export type Style = {
	Material: Enum.Material,
	MaterialVariant: string,
	Reflectance: number,
	CastShadow: boolean,
	SurfaceAppearance: SurfaceAppearance?,
	TextureID: string,
	DoubleSided: boolean,
}
export type BatchWriter = (EditableMesh, { number }, { Vector3 }) -> ()
export type Bucket = {
	Mesh: EditableMesh,
	Part: MeshPart?,
	Style: Style,
	Group: number,
	Origin: CFrame,
	Scale: number,
	BaseSize: Vector3,
	Count: number,
	Triangles: number,
	Vertices: number,
	Write: BatchWriter?,
	PendingIds: { number },
	PendingPositions: { Vector3 },
}
export type Record = {
	Handle: PartHandle,
	Bucket: Bucket,
	Geometry: Geometry,
	VertexIds: { number },
	FaceIds: { number },
	ColorId: number,
	ColorIds: { number },
	BaseColors: { Color3 },
	BaseAlphas: { number },
	NormalIds: { number },
	BaseNormals: { Vector3 },
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Transparency: number,
}
return {}
