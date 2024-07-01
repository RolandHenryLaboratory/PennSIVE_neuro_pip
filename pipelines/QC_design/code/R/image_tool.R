.libPaths(c("/misc/appl/R-4.1/lib64/R/library","/home/zhengren/Desktop/cluster_set_up/r_packages"))
library(shiny)
library(bslib)
library(shinydashboard)
library(neurobase)
library(scales)
library(DT)
library(tidyverse)
library(papayaWidget)
library(shinyjs)

qc_shiny = function(main_path){
  jsCode <- "
shinyjs.removeImage = function() {
  if (papayaContainers.length > 0) {
    var viewer = papayaContainers[0].viewer;
    viewer.screenVolumes = [];
    viewer.updateViewer(true);
  }
};
"
  ui = function(request) {
    files = list.files(main_path, recursive = TRUE, full.names = TRUE)
    rds_files = files[which(grepl(".rds$", files))]
    file_name = sapply(rds_files, function(x) basename(x), USE.NAMES = FALSE)
    fluidPage(
      useShinyjs(),  # Include shinyjs
    extendShinyjs(text = jsCode, functions = c("removeImage")),
      theme = bslib::bs_theme(version = 4, bootswatch = "minty"),
      titlePanel("WM Lesion Segmentation QC"),
      sidebarLayout(
        sidebarPanel(
          conditionalPanel(condition="input.tabselected==1",
                           fluidRow(
                             shinydashboard::box(  
                               width = NULL,
                               title = "Lesion Mask Evaluation",
                               uiOutput("evaluation_note")
                             )
                           ),
                           fluidRow(
                             shinydashboard::box(  
                               width = NULL,
                               actionButton("pass", "PASS"),
                               actionButton("fail", "FAIL")
                             )
                           ),
                           fluidRow(
                             shinydashboard::box(  
                               width = NULL,
                               title = "Notes",
                               textInput("note", "Add additional notes:", value = "")
                             )
                           ),
                           fluidRow(
                             shinydashboard::box(
                               width = 12,
                               title = "Detailed Information",
                               DT::DTOutput("info"))),
                           fluidRow(
                             shinydashboard::box(
                               width = 12,
                               title = "Lesion Investigation",
                               uiOutput("lesion_invest")))
          ),
          conditionalPanel(condition="input.tabselected==2",
                           shiny::uiOutput("login")
                           
          )
        ),
        mainPanel(
          tabsetPanel(
            tabPanel("Welcome", value = 2, 
                     shiny::uiOutput("welcome")),
            tabPanel("Interactive QC", value = 1, 
                     fluidRow(
                       shinydashboard::box(
                         width = 12,
                         title = "MRI",
                         shiny::uiOutput("img_control")))),
            id = "tabselected"
          )
        )
      )
    )
  }
  
  server = function(input, output, session) {
    files = list.files(main_path, recursive = TRUE, full.names = TRUE)
    rds_files = files[which(grepl(".rds$", files))]
    file_name = sapply(rds_files, function(x) basename(x), USE.NAMES = FALSE)
    result_list = reactiveVal(NULL)
    data = reactiveVal(NULL)
    user = reactiveVal(NULL)
    index = reactiveVal(NULL)
    rds_remain = reactiveVal(list.files(main_path, pattern = ".rds$", recursive = TRUE, full.names = TRUE))
    output$login = renderUI({
      user_name = user()
      if(is.null(user_name)){
        fluidRow(
          shinydashboard::box(
            width = 12,
            title = "User Log in",
            textInput("uname", "Please enter the user name:"),
            actionButton("login_button", "Log in")))
      }else{
        rds_check = rds_remain()
        if(length(rds_check) != 0){
          tagList(list(
            shiny::uiOutput("wc_user"),
            fluidRow(
              shinydashboard::box(  
                width = NULL,
                title = "Data Selection",
                selectInput("rds_file", "Choose a rds file", choices = file_name, selected = file_name[1]),
                actionButton("read_data", "Load Data")
              )
            ),
            shiny::uiOutput("transfer")))
        }else{
          csv_files = list.files(main_path, pattern = ".csv$", recursive = TRUE, full.names = TRUE)
          dir_name = unique(dirname(csv_files))
          fluidRow(
            shinydashboard::box(  
              width = NULL,
              title = "Compile Complete QC result",
              textInput("file_save_path_com", "Save compiled QC file to:", value = paste0(dir_name, "/WM_lesion_QC_result.csv")),
              actionButton("comp", "Compile"),
              verbatimTextOutput("output_msg_file_com")
            )
          )
        }
      }
    })
    
    output$wc_user = renderUI({
      user_name = user()
      HTML(paste0("Welcome: <strong>", user_name, "!</strong>"))
    })
    
    observeEvent(input$login_button, {
      user_name = input$uname
      user(user_name)
    })
    
    output$welcome = renderUI({
      user_name = user()
      if(is.null(user_name)){
        tagList(list(
          tags$h1("Welcome to our WM Lesion Segmentation QC Shiny App"),
          tags$h2("Description"),
          HTML("<br>"),
          HTML("The WM Lesion Segmentation QC Shiny App is a collaborative tool designed to facilitate the evaluation of white matter lesion masks generated by segmentation algorithms. It provides a user-friendly interface where multiple users can collectively assess lesion segmentation quality through interactive features. <br>"),
          tags$h2("Key Features"),
          HTML("<br>"),
          HTML("<strong>Subject Evaluation:</strong> Users can select pass or fail for each subject's lesion segmentation, enabling efficient evaluation of segmentation quality. <br><br>"),
          HTML("<strong>Interactive Interface:</strong> The app offers an intuitive and interactive interface for seamless navigation and evaluation. <br><br>"),
          HTML("<strong>Automated Recording:</strong> Evaluation results are automatically recorded in an Excel file, ensuring accurate and efficient documentation of assessment outcomes. <br><br>"),
          HTML("<strong>Additional Notes:</strong> Users have the option to include additional notes during the evaluation process, providing flexibility and context to the assessment. <br><br>"),
          HTML("<br>"),
          HTML("<strong><span style='color: purple;'>Overall, the WM Lesion Segmentation QC Shiny App empowers users to efficiently and collaboratively evaluate lesion segmentation quality, contributing to improved accuracy and reliability in neuroimaging research and clinical applications.</span></strong> <br>"),
          HTML("<br><br>"),
          HTML("Please <strong><span style='color: red;'>log in</span></strong> to continue. <br>")
        ))
        
      }else{
        fluidRow(
          shinydashboard::box(
            width = 12,
            title = "Summary",
            DT::DTOutput("qc_df")))
      }
    })
    
    observeEvent(input$read_data, {
      # Simulate removing the first item from the dataset
      file = rds_files[which(basename(file_name) == input$rds_file)]
      msg = sprintf('Loading Data...')
      withProgress(message = msg, value = 0, {
        setProgress(0.5, 'Loading...')
        load_data = readRDS(file)
        setProgress(1, 'Complete!')
      })
      showNotification('Data successfully loaded!', type = "message")
      
      result_list(load_data)
      data(load_data$summary_df)
      rds_files = rds_remain()
      file_name = sapply(rds_files, function(x) basename(x), USE.NAMES = FALSE)
      updateTextInput(session, "model_save_path", value = rds_files[which(basename(file_name) == input$rds_file)])
      i = which(is.na(load_data$summary_df[["evaluation"]]))[1]
      index(i)
    })
    
    output$transfer = renderUI({
      new_data = data()
      rds_files = rds_remain()
      if(!is.null(new_data)){
        i = which(is.na(new_data[["evaluation"]]))[1]
        if(is.na(i)){
          fluidRow(
            shinydashboard::box(  
              width = NULL,
              title = "Transform Data",
              textInput("file_save_path", "Save completed QC file to:", value = gsub(".rds", ".csv", rds_files[which(basename(file_name) == input$rds_file)])),
              actionButton("trans", "Transform"),
              verbatimTextOutput("output_msg_file")
            )
          )
        }else{
          fluidRow(
            shinydashboard::box(  
              width = NULL,
              title = "Save Result",
              textInput("model_save_path", "Save QC work in progress result to:", value = rds_files[which(basename(file_name) == input$rds_file)]),
              actionButton("Save", "Save"),
              verbatimTextOutput("output_msg_model")
            )
          )
        }
      }
    })
    
    output$evaluation_note = renderUI({
      tagList(list(
      HTML("Please select <strong><span style='color: green;'>PASS</span></strong> if you believe the lesion segmentation is of high quality. Otherwise, please select <strong><span style='color: red;'>FAIL</span></strong>."),
      HTML("<br>"),
      HTML("<br>")
      ))
    })
    
    observeEvent(input$pass, {
      # Simulate removing the first item from the dataset
      new_data = data()
      if(!is.na(input$note) & input$note != ""){
        new_data[which(is.na(new_data[["evaluation"]])),][1,"note"] = input$note
      }
      new_data[which(is.na(new_data[["evaluation"]])),][1,"evaluator"] = user()
      new_data[which(is.na(new_data[["evaluation"]])),][1,"evaluation"] = "pass"
      
      # Update the dataset
      data(new_data)
      updateTextInput(session, "note", value = "")
      i = which(is.na(new_data[["evaluation"]]))[1]
      index(i)
      updateSelectInput(session, "lesion_id", selected = "all")
      js$removeImage() 
      gc()
    })
    
    observeEvent(input$fail, {
      new_data = data()
      if(!is.na(input$note) & input$note != ""){
        new_data[which(is.na(new_data[["evaluation"]])),][1,"note"] = input$note
      }
      new_data[which(is.na(new_data[["evaluation"]])),][1,"evaluator"] = user()
      new_data[which(is.na(new_data[["evaluation"]])),][1,"evaluation"] = "fail"
      
      # Update the dataset
      data(new_data)
      updateTextInput(session, "note", value = "")
      updateTextInput(session, "model_save_path", value = rds_files[which(basename(file_name) == input$rds_file)])
      i = which(is.na(new_data[["evaluation"]]))[1]
      index(i)
      updateSelectInput(session, "lesion_id", selected = "all")
      js$removeImage() 
      gc()
    })
    
    output$img_control = renderUI({
      new_data = data()
      i = which(is.na(new_data[["evaluation"]]))[1]
      if(!is.na(i)){
        fluidRow(
        papayaOutput("image", height = "600px"))
      }else{
        shiny::uiOutput("finish")
      }
    })
    
    output$image = renderPapaya({
      new_data = data()
      i = which(is.na(new_data[["evaluation"]]))[1]
      if(!is.na(i)){
        qc_list = result_list()
        if(new_data[i, "lesion_num"] > 0){
          if(input$lesion_id == "all"){
            papaya(img=list(qc_list$flair_imgs[[i]], qc_list$mimosa_imgs[[i]]), sync_view = TRUE, 
                   hide_toolbar = FALSE, hide_controls = TRUE, 
                   orthogonal = TRUE, options = list(papayaOptions(alpha = 0.5),
                                                     papayaOptions(alpha = 0.5, lut = "Red Overlay")))                                       
          }else{papaya(img=list(qc_list$flair_imgs[[i]], qc_list$labeled_lesion[[i]]==as.numeric(gsub("lesion ", "", input$lesion_id))), sync_view = TRUE, 
                       hide_toolbar = FALSE, hide_controls = TRUE, 
                       orthogonal = TRUE, options = list(papayaOptions(alpha = 0.5),
                                                         papayaOptions(alpha = 0.5, lut = "Red Overlay")))}
        }else{
         papaya(qc_list$flair_imgs[[i]])
        }
      }
    })
    
    output$finish = renderUI({
      HTML(print("All images successfully evaluated!"))
    })
    
    output$info = DT::renderDT({
      info_df = data()
      if(!is.null(info_df)){
        
        if("max_lesion_prob" %in% colnames(info_df)){
          selected_column = c("subject", "session", "lesion_num", "max_lesion_prob", "mean_lesion_prob", "min_lesion_prob")
        }else(selected_column = c("subject", "session", "lesion_num"))
        
        info_df %>% filter(is.na(evaluation)) %>% head(1) %>% dplyr::select(selected_column) %>% 
          DT::datatable(options = list(columnDefs = list(list(className = 'dt-center', 
                                                              targets = "_all")))) 
      }
    })
    
    output$lesion_invest = renderUI({
      new_data = data()
      i = which(is.na(new_data[["evaluation"]]))[1]
      if(!is.na(i) & new_data[i, "lesion_num"] > 0){
        lesion_id = paste0("lesion ", 1:new_data[i, "lesion_num"])
        selectInput("lesion_id", "Select a lesion to further investigate:", choices = c("all",lesion_id), selected = "all")
      }
    })
    
    output$qc_df = DT::renderDT({
      df = data()
      if(!is.null(df)){
        df %>% arrange(desc(evaluation)) %>% 
          DT::datatable(options = list(columnDefs = list(list(className = 'dt-center', 
                                                              targets = "_all")))) %>% formatStyle(
                                                                'evaluation',
                                                                target = 'row',
                                                                backgroundColor = styleEqual(c("fail"), "lightyellow")
                                                              )
      }
    })
    
    observeEvent(input$Save,{
      model_save_path = input$model_save_path
      qc_list = result_list()
      qc_list$summary_df = data()
      msg = sprintf('Saving work in progress result...')
      withProgress(message = msg, value = 0, {
        setProgress(0.5, 'Saving...')
        saveRDS(qc_list, file = model_save_path)
        setProgress(1, 'Complete!')
      })
      showNotification('QC work in progress result successfully saved!', type = "message")
    })
    
    output$output_msg_model <- renderPrint({
      paste("QC work in progress result saved to:", input$model_save_path)
    })
    
    observeEvent(input$trans,{
      file_save_path = input$file_save_path
      complete_qc = data()
      msg = sprintf('Saving completed QC results ...')
      withProgress(message = msg, value = 0, {
        setProgress(0.5, 'Saving...')
        write_csv(complete_qc, file_save_path)
        setProgress(1, 'Complete!')
      })
      showNotification('Completed QC result successfully saved!', type = "message")
      
      msg2 = sprintf('Removing work in progress data ...')
      withProgress(message = msg2, value = 0, {
        setProgress(0.5, 'Removing ...')
        file.remove(rds_files[which(basename(file_name) == input$rds_file)])
        setProgress(1, 'Complete!')
      })
      showNotification('Work in process data successfully removed!', type = "message")
      files = list.files(main_path, recursive = TRUE, full.names = TRUE)
      rds_files = files[which(grepl(".rds$", files))]
      file_name = sapply(rds_files, function(x) basename(x), USE.NAMES = FALSE)
      rds_remain(rds_files)
      updateSelectInput(session, "rds_file", choices = file_name, selected = file_name[1])
      data(NULL)
      result_list(NULL)
      gc()
      #session$reload()
    })
    
    observeEvent(input$comp,{
      file_save_path = input$file_save_path_com
      csv_files = list.files(main_path, pattern = ".csv$", recursive = TRUE, full.names = TRUE)
      msg = sprintf('Saving completed QC results ...')
      withProgress(message = msg, value = 0, {
        setProgress(0.5, 'Saving...')
        compiled_df = csv_files %>% read_csv %>% bind_rows
        write_csv(compiled_df, file_save_path)
        setProgress(1, 'Complete!')
      })
      showNotification('Compiled QC result successfully saved!', type = "message")
      
      msg2 = sprintf('Removing separate QC results ...')
      withProgress(message = msg2, value = 0, {
        setProgress(0.5, 'Removing ...')
        file.remove(csv_files)
        setProgress(1, 'Complete!')
      })
      showNotification('Separate QC results successfully removed!', type = "message")
      files = list.files(main_path, recursive = TRUE, full.names = TRUE)
      rds_files = files[which(grepl(".rds$", files))]
      file_name = sapply(rds_files, function(x) basename(x), USE.NAMES = FALSE)
      updateSelectInput(session, "rds_file", choices = file_name, selected = file_name[1])
    })
    
    output$output_msg_file <- renderPrint({
      paste("Completed QC Result saved to:", input$file_save_path)
    })
    
    output$output_msg_file_com <- renderPrint({
      paste("Compiled QC Result saved to:", input$file_save_path_com)
    })
    
  }
  
  shinyApp(ui = ui, server = server, enableBookmarking = "url")
  
}

