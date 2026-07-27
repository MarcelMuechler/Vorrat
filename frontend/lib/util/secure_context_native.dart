/// Native builds talk to the camera through the platform, not `navigator`,
/// so the page's origin never gates it.
bool get cameraBlockedByInsecureOrigin => false;
