@testitem "It should not be possible to create an inference engine for an unsupported model backend" begin
    import Cortex: UnsupportedModelBackendError

    @test_throws UnsupportedModelBackendError(1) Cortex.InferenceEngine(model_backend = 1)
    @test_throws UnsupportedModelBackendError("string") Cortex.InferenceEngine(model_backend = "string")

    @test_throws "The model backend of type `Int64` is not supported." Cortex.InferenceEngine(model_backend = 1)
    @test_throws "The model backend of type `String` is not supported." Cortex.InferenceEngine(model_backend = "string")

    # Test with a custom, unsupported struct type
    struct MyDummyUnsupportedBackend end

    dummy_backend = MyDummyUnsupportedBackend()
    @test_throws UnsupportedModelBackendError(dummy_backend) Cortex.InferenceEngine(model_backend = dummy_backend)
end