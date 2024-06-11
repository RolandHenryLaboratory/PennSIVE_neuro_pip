suppressMessages(library(argparser))
suppressMessages(library(shiny))
suppressMessages(library(shinyAce))
suppressMessages(library(bslib))
suppressMessages(library(shinydashboard))
suppressMessages(library(tidyverse))
suppressMessages(library(DT))

p <- arg_parser("Customizing your heuristic.py for bids curation.", hide.opts = FALSE)
p <- add_argument(p, "--mainpath", short = '-m', help = "Specify the main path where MRI images can be found.")
argv <- parse_args(p)

main_path = argv$mainpath
files = list.files(paste0(main_path, "/dicominfo"), recursive = TRUE, full.names = TRUE)
n = length(files)
py_scripts = list.files(paste0(main_path, "/heuristic_script"), pattern = "*.py$", recursive = TRUE, full.names = TRUE)
py_scripts = py_scripts[which(!grepl("template", py_scripts))]

# Define UI
ui <- fluidPage(
  titlePanel("BIDS Heuristic Customization"),
  sidebarLayout(
    sidebarPanel(
      fileInput("file", "Choose Python Script"),
      actionButton("update", "Update Script"),
      actionButton("update_all", "Update All Scripts"),
      tags$div(style = "height: 20px;"),
      fluidRow(
        shinydashboard::box(  
          width = NULL,
          title = "DICOM Selection",
          uiOutput("control_button")
        )
      ),
      tags$div(style = "height: 20px;"),
      fluidRow(
        shinydashboard::box(  
          width = NULL,
          title = "Update Heuristic Script",
          aceEditor("script", "Python Script", mode = "python", height = "700px", theme = "tomorrow_night_blue")
        )
      )
    ),
    mainPanel(
      fluidRow(
        shinydashboard::box(  
          width = NULL,
          title = "DICOM Info Review",
          DT::DTOutput("dicom_info")
        )
      )
    )
  )
)

# Define server logic
server <- function(input, output, session) {
  
  i <- reactiveVal(1)
  
  output$control_button <- renderUI({
    if(i() == 1){
      fluidRow(
          column(width = 1), 
          column(width = 5, 
          actionButton("next_button", "Next")
          )
      )
    }else if(i() == n){
      fluidRow(
          column(width = 1), 
          column(width = 5, 
          actionButton("previous_button", "Previous")
          )
      )
    }else{
    fluidRow(
        column(width = 1), 
        column(width = 5, 
        actionButton("next_button", "Next")),
        column(width = 5,
        actionButton("previous_button", "Previous"))
    )
    }
  })
  
  observeEvent(input$file, {
    req(input$file)
    file <- input$file$datapath
    script <- readLines(file)
    updateAceEditor(session, "script", value = paste(script, collapse = "\n"))
  })
  
  observeEvent(input$update, {
    script <- isolate(input$script)
    index <- i()
    p <- strsplit(files[index], "/")[[1]][length(strsplit(files[index], "/")[[1]]) - 2]
    s <- strsplit(files[index], "/")[[1]][length(strsplit(files[index], "/")[[1]]) - 1]
    writeLines(unlist(strsplit(script, "\n")), paste0(main_path, "/heuristic_script/template/heuristic.py"))
    writeLines(unlist(strsplit(script, "\n")), paste0(main_path, "/heuristic_script/", p, "/", s, "/heuristic.py"))
    showModal(modalDialog(
      title = "Script Saved",
      "The Python script has been successfully saved."
    ))
  })

  observeEvent(input$update_all, {
    script <- isolate(input$script)
    writeLines(unlist(strsplit(script, "\n")), paste0(main_path, "/heuristic_script/template/heuristic.py"))
    for (i in 1:length(py_scripts)){
      writeLines(unlist(strsplit(script, "\n")), py_scripts[i])
    }
    showModal(modalDialog(
      title = "All Scripts Saved",
      "All Python scripts have been successfully saved."
    ))
  })
  
  observeEvent(input$next_button, {
    i(i() + 1)
  })
  
  observeEvent(input$previous_button, {
    i(i() - 1)
  })
  
  output$dicom_info = DT::renderDT({
    index <- i()
    dicom_file <- files[index]
    info_df <- read.table(dicom_file, header = TRUE, sep = "\t")
    info_df %>% dplyr::select(protocol_name, series_id, dim1, dim2, dim3, dim4, TR, TE, study_description, image_type) %>% 
      DT::datatable(options = list(columnDefs = list(list(className = 'dt-center', 
                                                          targets = "_all")))) %>% formatStyle(
                                                            "protocol_name",
                                                            backgroundColor = "pink"
                                                          )
  })
  
}

# Run the application
shinyApp(ui = ui, server = server)