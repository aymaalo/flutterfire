// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_vertex_ai/firebase_vertex_ai.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as google_ai;

const _baseUrl = 'staging-firebaseml.sandbox.googleapis.com';
const _apiVersion = 'v2beta';

/// A multimodel generative model (like Gemini).
///
/// Allows generating content, creating embeddings, and counting the number of
/// tokens in a piece of content.
final class GenerativeModel {
  final String _modelName;
  final FirebaseApp _firebaseApp;
  final FirebaseAppCheck _appCheck;
  final List<SafetySetting> _safetySettings;
  final GenerationConfig? _generationConfig;
  final String _location;
  final google_ai.GenerativeModel _model;

  /// Create a [GenerativeModel] backed by the generative model named [model].
  ///
  /// The [model] argument can be a model name (such as `'gemini-pro'`) or a
  /// model code (such as `'models/gemini-pro'`).
  /// There is no creation time check for whether the `model` string identifies
  /// a known and supported model. If not, attempts to generate content
  /// will fail.
  ///
  /// A Google Cloud [apiKey] is required for all requests.
  /// See documentation about [API keys][] for more information.
  ///
  /// [API keys]: https://cloud.google.com/docs/authentication/api-keys "Google Cloud API keys"
  ///
  /// The optional [safetySettings] and [generationConfig] can be used to
  /// control and guide the generation. See [SafetySetting] and
  /// [GenerationConfig] for details.
  ///
  /// Content creation requests are sent to a server through the [httpClient],
  /// which can be used to control, for example, the number of allowed
  /// concurrent requests.
  /// If the `httpClient` is omitted, a new [http.Client] is created for each
  /// request.
  GenerativeModel({
    required String modelName,
    required String apiKey,
    required String location,
    required FirebaseApp app,
    List<SafetySetting>? safetySettings,
    GenerationConfig? generationConfig,
  })  : _modelName = _normalizeModelName(modelName),
        _firebaseApp = app,
        _appCheck = FirebaseAppCheck.instance,
        _safetySettings = safetySettings ?? [],
        _generationConfig = generationConfig,
        _location = location,
        _model = google_ai.GenerativeModel(
            model: _normalizeModelName(modelName),
            apiKey: apiKey,
            safetySettings: safetySettings != null
                ? safetySettings
                    .map((setting) => setting.toGoogleAISafetySetting())
                    .toList()
                : [],
            generationConfig:
                _convertGenerationConfig(generationConfig, app, location));

  static const _modelsPrefix = 'models/';
  static String _normalizeModelName(String modelName) =>
      modelName.startsWith(_modelsPrefix)
          ? modelName.substring(_modelsPrefix.length)
          : modelName;

  static google_ai.VertexConfig _vertexConfig(
      FirebaseApp app, String location) {
    var projectId = app.options.projectId;
    var uri = Uri.https(
      _baseUrl,
      '/$_apiVersion/projects/$projectId/locations/$location/publishers/google/',
    );
    return google_ai.VertexConfig(modelUri: uri);
  }

  static google_ai.GenerationConfig _convertGenerationConfig(
      GenerationConfig? config, FirebaseApp app, String location) {
    var vertexConfig = _vertexConfig(app, location);
    if (config == null) {
      return google_ai.GenerationConfig(vertexConfig: vertexConfig);
    } else {
      return config.toGoogleAIGenerationConfig(vertexConfig);
    }
  }

  /// Generates content responding to [prompt].
  ///
  /// Sends a "generateContent" API request for the configured model,
  /// and waits for the response.
  ///
  /// Example:
  /// ```dart
  /// final response = await model.generateContent([Content.text(prompt)]);
  /// print(response.text);
  /// ```
  Future<GenerateContentResponse> generateContent(Iterable<Content> prompt,
      {List<SafetySetting>? safetySettings,
      GenerationConfig? generationConfig}) async {
    Iterable<google_ai.Content> googlePrompt =
        prompt.map((content) => content.toGoogleAIContent());
    List<google_ai.SafetySetting> googleSafetySettings = safetySettings != null
        ? safetySettings
            .map((setting) => setting.toGoogleAISafetySetting())
            .toList()
        : [];
    return _model
        .generateContent(googlePrompt,
            safetySettings: googleSafetySettings,
            generationConfig: _convertGenerationConfig(
                generationConfig, _firebaseApp, _location))
        .then((value) =>
            GenerateContentResponse.fromGoogleAIGenerateContentResponse(value));
  }

  /// Generates a stream of content responding to [prompt].
  ///
  /// Sends a "streamGenerateContent" API request for the configured model,
  /// and waits for the response.
  ///
  /// Example:
  /// ```dart
  /// final responses = await model.generateContent([Content.text(prompt)]);
  /// await for (final response in responses) {
  ///   print(response.text);
  /// }
  /// ```
  Stream<GenerateContentResponse> generateContentStream(
      Iterable<Content> prompt,
      {List<SafetySetting>? safetySettings,
      GenerationConfig? generationConfig}) {
    return _model
        .generateContentStream(
            prompt.map((content) => content.toGoogleAIContent()),
            safetySettings: safetySettings != null
                ? safetySettings
                    .map((setting) => setting.toGoogleAISafetySetting())
                    .toList()
                : [],
            generationConfig: generationConfig?.toGoogleAIGenerationConfig(
                _vertexConfig(_firebaseApp, _location)))
        .map((event) =>
            GenerateContentResponse.fromGoogleAIGenerateContentResponse(event));
  }

  /// Counts the total number of tokens in [contents].
  ///
  /// Sends a "countTokens" API request for the configured model,
  /// and waits for the response.
  ///
  /// Example:
  /// ```dart
  /// final promptContent = [Content.text(prompt)];
  /// final totalTokens =
  ///     (await model.countTokens(promptContent)).totalTokens;
  /// if (totalTokens > maxPromptSize) {
  ///   print('Prompt is too long!');
  /// } else {
  ///   final response = await model.generateContent(promptContent);
  ///   print(response.text);
  /// }
  /// ```
  Future<CountTokensResponse> countTokens(Iterable<Content> contents) async {
    return _model.countTokens(contents.map((e) => e.toGoogleAIContent())).then(
        (value) => CountTokensResponse.fromGoogleAICountTokensResponse(value));
  }

  /// Creates an embedding (list of float values) representing [content].
  ///
  /// Sends a "embedContent" API request for the configured model,
  /// and waits for the response.
  ///
  /// Example:
  /// ```dart
  /// final promptEmbedding =
  ///     (await model.embedContent([Content.text(prompt)])).embedding.values;
  /// ```
  Future<EmbedContentResponse> embedContent(Content content,
      {TaskType? taskType, String? title}) async {
    return _model
        .embedContent(content.toGoogleAIContent(),
            taskType: taskType?.toGoogleAITaskType(), title: title)
        .then((value) =>
            EmbedContentResponse.fromGoogleAIEmbedContentResponse(value));
  }
}