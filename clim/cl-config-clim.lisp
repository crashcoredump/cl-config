(in-package :cfg.clim)

(define-application-frame configuration-schema-viewer ()
  ((configuration-schema
    :initarg :configuration-schema
    :accessor configuration-schema
    :initform (error "Provide the configuration schema")))
  (:pane
   (flet ((label (string)
            (make-pane 'label-pane :label string)))
     (with-slots (configuration-schema) *application-frame*
       (scrolling (:width 1500 :height 800)
         (labelling (:label (title configuration-schema))
           (vertically ()
             (labelling (:label "Overview")
               (make-pane 'application-pane
                          :height 100
                          :display-function
                          (lambda (frame pane)
                            (declare (ignore frame))
                          
                            (format pane "~A" (cfg::documentation* configuration-schema))
                            (let ((parents (slot-value configuration-schema 'cfg::parents)))
                              (if parents
                                  (progn
                                    (terpri pane) (terpri pane)
                                    (format pane "~A" "Parents: ")
                                    (let ((parent (cfg::find-configuration-schema (first parents))))
                                      (with-output-as-presentation (pane parent 'configuration-schema)
                                        (format pane "~A" (cfg::title parent)))
                                      (loop for parent-name in (cdr parents)
                                         do
                                         (let ((parent (cfg::find-configuration-schema parent-name)))
                                           (with-output-as-presentation (pane parent 'configuration-schema)
                                             (format pane ", ~A" (cfg::title parent)))))))
                                  (format pane "~A" "No parents"))))))
             (make-pane 'vrack-pane :contents
                        (loop for section being the hash-values of
                             (cfg::sections configuration-schema)
                             collect
                             (labelling (:label (title section))
                               (make-pane 'table-pane
                                          :contents
                                          (loop for option-schema being the hash-values of (cfg::direct-options section)
                                             collect
                                               (append
                                                (mapcar #'label
                                                        (list
                                                         (prin1-to-string (cfg::name option-schema))
                                                         (title option-schema)
                                                         (if (cfg::optional option-schema)
                                                             "Yes" "No")
                                                         (if (slot-boundp option-schema 'cfg::default)
                                                             (prin1-to-string (cfg::default option-schema))
                                                             "--")
                                                         (if (cfg::advanced option-schema)
                                                             "Yes" "No")))
                                                (list
                                                 (let ((pane
                                                        (make-pane 'application-pane
                                                                   :width 50
                                                                   :height 50
                                                                   :display-function
                                                                   (let ((option-schema option-schema))
                                                                     (lambda (frame pane)
                                                                       (format pane "~A" (or (cfg::documentation* option-schema) ""))
                                                                       )))))                                                   
                                                   pane)))))))))))))))

(define-application-frame configuration-editor ()
  ((configuration :initarg :configuration
                  :accessor configuration
                  :initform (error "Provide the configuration")))
  (:pane
   (flet ((label (string)
            (make-pane 'label-pane :label string)))
     (with-slots (configuration) *application-frame*
       (scrolling (:width 1000 :height 600)
         (make-pane 'vrack-pane :contents
                    (append
                     (list
                      (labelling (:label "Overview")
                        (label (cfg::documentation* configuration))))
                     (loop for section being the hash-values of
                          (cfg::sections (cfg::configuration-schema configuration))
                          collect
                          (labelling (:label (title section))
                            (make-configuration-section-pane configuration section))))))))))

(defun make-configuration-section-pane (configuration section)
  (let
      ((direct-options (cfg::direct-options-list section
                                            :exclude-advanced t)))
    (make-pane 'table-pane
               :contents
               (loop for option in direct-options
                  collect
                    (list
                     (make-pane 'label-pane :label (title option))
                     (make-configuration-option-editor configuration section option))))))
           
(defun make-configuration-option-editor (configuration section option)
  (multiple-value-bind (value option-instance section-instance origin)
	(cfg::get-option-value
	  (list (cfg::name section)
		(cfg::name option))
	  configuration nil)
    (make-configuration-option-editor-valued (cfg::option-type option)
                                             option
                                             option-instance
                                             value)))

(defgeneric make-configuration-option-editor-valued (type option-schema option value))

(defmethod make-configuration-option-editor-valued (cfg::text-configuration-schema-option-type
                                                    option-schema
                                                    option
                                                    value)
  (make-pane 'text-field
             :value value))

(defmethod make-configuration-option-editor-valued ((type cfg::integer-configuration-schema-option-type)
                                                    option-schema
                                                    option
                                                    value)
  ;; (make-pane 'slider :min-value 0 :max-value 100 :value value)
  (make-pane 'text-field :value value)
  )

(defmethod make-configuration-option-editor-valued ((type cfg::one-of-configuration-schema-option-type)
                                                    option-schema
                                                    option
                                                    value)
  (make-pane 'option-pane
             :items (cfg::options type)
             :value (find value (cfg::options type) :key #'cfg::name)
             :name-key #'cfg::title))

(defmethod make-configuration-option-editor-valued ((type cfg::list-configuration-schema-option-type)
                                                    option-schema
                                                    option
                                                    value)
   (make-pane 'list-pane
              :mode :nonexclusive
              :items (cfg::options type)
              :name-key #'cfg::title
              :value (find value (cfg::options type) :key #'cfg::name)))

(defmethod make-configuration-option-editor-valued ((type cfg::boolean-configuration-schema-option-type)
                                                    option-schema
                                                    option
                                                    value)
  (make-pane 'toggle-button :value value))

(defmethod make-configuration-option-editor-valued ((type cfg::pathname-configuration-schema-option-type)
                                                    option-schema
                                                    option
                                                    value)
  (make-configuration-option-editor-valued 'cfg::text-configuration-schema-option-type
                                           option-schema
                                           option
                                           value))
                                                    
(defmethod make-configuration-option-editor-valued ((type cfg::email-configuration-schema-option-type)
                                                    option-schema
                                                    option
                                                    value)
  (make-configuration-option-editor-valued 'cfg::text-configuration-schema-option-type
                                           option-schema
                                           option
                                           value))

(defmethod make-configuration-option-editor-valued ((type cfg::url-configuration-schema-option-type)
                                                    option-schema
                                                    option
                                                    value)
  (make-configuration-option-editor-valued 'cfg::text-configuration-schema-option-type
                                           option-schema
                                           option
                                           value))

(define-presentation-type configuration-schema ())

(define-presentation-to-command-translator configuration-schema-to-view-command
    (configuration-schema
     com-view-configuration-schema
     configuration-schema-viewer
     :gesture :select
     :documentation "View this configuration schema")
    (object)
  (list object))

(define-configuration-schema-viewer-command (com-view-configuration-schema :name "View configuration schema")
    ((configuration-schema 'configuration-schema))
  (sb-thread:make-thread (lambda ()
                           (run-frame-top-level
                            (make-application-frame 'configuration-schema-viewer
                                                    :configuration-schema configuration-schema)))))
  
(defun run-configuration-editor (configuration)
  (run-frame-top-level
   (make-application-frame 'configuration-editor :configuration configuration)))

(defun run-configuration-schema-viewer (configuration-schema)
  (run-frame-top-level
   (make-application-frame 'cfg.clim::configuration-schema-viewer
                           :configuration-schema configuration-schema)))

(defun run-configuration-schema-viewer-example ()
  (cl-config::load-examples)
  (run-configuration-schema-viewer
   (cl-config::find-configuration-schema 'cfg::standard-configuration)))

(define-application-frame list-configuration-editor ()
  ((configuration :initarg :configuration
                  :accessor configuration
                  :initform (error "Provide the configuration")))
  (:panes
   (sections-pane
    (with-slots (configuration) *application-frame*
      (let ((sections (loop for section being the hash-values of
                           (cfg::sections (cfg::configuration-schema configuration))
                           collect section)))
        (make-pane 'climi::extended-list-pane
                   :items sections
                   :name-key #'cfg::title
                   :value-changed-callback
                   (lambda (pane section)
                     (declare (ignore pane))
                     (let ((section-configuration-pane
                            (find-pane-named *application-frame* 'section-configuration-pane)))
                       (sheet-disown-child section-configuration-pane
                                           (first (sheet-children section-configuration-pane)))
                       (clim:with-look-and-feel-realization ((clim:frame-manager clim:*application-frame*)
                                                             clim:*application-frame*)
                         (sheet-adopt-child section-configuration-pane
                                            (make-configuration-section-pane configuration section)))))
                   :item-padding (climi::make-padding 10 5 10 5)))))
   (section-configuration-pane
    (scrolling (:height 500)
      (with-slots (configuration) *application-frame*
        (let ((sections (loop for section being the hash-values of
                             (cfg::sections (cfg::configuration-schema configuration))
                           collect section)))
          (make-configuration-section-pane configuration (first sections))))))
   (apply-button (make-pane 'push-button :label "Apply"))
   (cancel-button (make-pane 'push-button :label "Cancel")))
  (:layouts
   (default
       (vertically ()
         (horizontally ()
           (1/3 (scrolling(:height 500)
                  sections-pane))
           (2/3 section-configuration-pane))
         (horizontally ()
           apply-button cancel-button)))))

(defun run-list-configuration-editor (configuration)
  (run-frame-top-level
   (make-application-frame 'list-configuration-editor :configuration configuration)))