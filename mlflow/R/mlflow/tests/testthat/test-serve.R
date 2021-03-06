context("Serve")

test_that("mlflow can serve a model function", {
  mlflow_clear_test_dir("model")

  model <- lm(Sepal.Width ~ Sepal.Length + Petal.Width, iris)

  fn <- crate(~ stats::predict(model, .x), model)
  mlflow_save_model(fn)

  expect_true(dir.exists("model"))

  model_server <- processx::process$new(
    "Rscript",
    c(
      "-e",
      "mlflow::mlflow_rfunc_serve('model', browse = FALSE)"
    ),
    supervise = TRUE,
    stdout = "|",
    stderr = "|"
  )

  Sys.sleep(5)

  tryCatch({
    status_code <- httr::status_code(httr::GET("http://127.0.0.1:8090"))
  }, error = function(e) {
    stop(e$message, ": ", paste(model_server$read_all_error_lines(), collapse = "\n"))
  })

  expect_equal(status_code, 200)

  newdata <- iris[1:2, c("Sepal.Length", "Petal.Width")]

  http_prediction <- httr::content(
    httr::POST(
      "http://127.0.0.1:8090/predict/",
      body = jsonlite::toJSON(as.list(newdata))
    )
  )
  if (is.character(http_prediction)) {
    stop(http_prediction)
  }

  model_server$kill()

  expect_equal(
    unlist(http_prediction$predictions),
    as.vector(predict(model, newdata)),
    tolerance = 1e-5
  )
})
