#include <raylib.h>

void workaroundDrawTextureRec(Texture2D texture, const Rectangle* sourceRec, int x, int y, const Color* tint);

#ifdef workaround_implementation
void workaroundDrawTextureRec(Texture2D texture, const Rectangle* sourceRec, int x, int y, const Color* tint) {
	DrawTextureRec(
		texture, *sourceRec, (Vector2) {x, y}, *tint
	);
}
#endif

void workaroundScreenToWorld2D(const Vector2* position, const Camera2D* camera, Vector2* out);

#ifdef workaround_implementation

void workaroundScreenToWorld2D(const Vector2* position, const Camera2D* camera, Vector2* out) {
	*out = GetScreenToWorld2D(*position, *camera);
}
#endif