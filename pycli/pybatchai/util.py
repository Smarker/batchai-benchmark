def set_properties(_self, **kwargs):
    """Set multiple object properties."""
    for key, value in kwargs.items():
        setattr(_self, key, value)
