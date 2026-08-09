# MandazaTV Samsung intake

- Product: MandazaTV 1.3.0, maintained by Luke Steuber.
- Target: Samsung Tizen TV (`tizen`), explicitly selected.
- Source spine: offline HTML canvas bundle adapted from Luke Steuber's MIT-licensed Mandaza web renderer.
- Test device: Samsung UN50TU8000FXZA at the local developer endpoint.
- Toolchain: Tizen Studio 2.5.25, Samsung TV extensions, and SDB 4.2.36 are installed on the Galactus volume.
- Accessibility gate: remote-only primary flow, visible focus, readable TV-distance controls, labels/status announcements, and explicit Back/Exit behavior.
- Initial risk: the physical TV may require a Samsung author/distributor certificate containing its DUID before accepting a widget.
- Next route: `platforms-tv`, adapter `tizen`.
