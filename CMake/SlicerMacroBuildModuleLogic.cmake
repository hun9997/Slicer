################################################################################
#
#  Program: 3D Slicer
#
#  Copyright (c) 2010 Kitware Inc.
#
#  See Doc/copyright/copyright.txt
#  or http://www.slicer.org/copyright/copyright.txt for details.
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
#  This file was originally developed by Jean-Christophe Fillion-Robin, Kitware Inc.
#  and was partially funded by NIH grant 3P41RR013218-12S1
#
################################################################################

#
# SlicerMacroBuildModuleLogic
#

MACRO(SlicerMacroBuildModuleLogic)
  SLICER_PARSE_ARGUMENTS(MODULELOGIC
    "NAME;EXPORT_DIRECTIVE;SRCS;INCLUDE_DIRECTORIES;TARGET_LIBRARIES"
    ""
    ${ARGN}
    )

  # Sanity checks
  IF(NOT DEFINED MODULELOGIC_NAME)
    MESSAGE(SEND_ERROR "NAME is mandatory")
  ENDIF(NOT DEFINED MODULELOGIC_NAME)

  IF(NOT DEFINED MODULELOGIC_EXPORT_DIRECTIVE)
    MESSAGE(SEND_ERROR "EXPORT_DIRECTIVE is mandatory")
  ENDIF(NOT DEFINED MODULELOGIC_EXPORT_DIRECTIVE)

  # Define library name
  SET(lib_name ${MODULELOGIC_NAME})
  
  # --------------------------------------------------------------------------
  # Find Slicer3

  IF(NOT Slicer_SOURCE_DIR)
    FIND_PACKAGE(Slicer REQUIRED)
    INCLUDE(${Slicer_USE_FILE})
    slicer3_set_default_install_prefix_for_external_projects()
  ENDIF(NOT Slicer_SOURCE_DIR)

  # --------------------------------------------------------------------------
  # Include dirs

  INCLUDE_DIRECTORIES(
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_BINARY_DIR}
    ${Slicer_Libs_INCLUDE_DIRS}
    ${Slicer_Base_INCLUDE_DIRS}
    ${MRMLLogic_SOURCE_DIR}
    ${MRMLLogic_BINARY_DIR}
    ${MODULELOGIC_INCLUDE_DIRECTORIES}
    )

  SET(MY_LIBRARY_EXPORT_DIRECTIVE ${MODULELOGIC_EXPORT_DIRECTIVE})
  SET(MY_EXPORT_HEADER_PREFIX ${MODULELOGIC_NAME})
  SET(MY_LIBNAME ${lib_name})
  
  IF (NOT EXISTS ${Slicer_EXPORT_HEADER_TEMPLATE})
    MESSAGE("Warning, Slicer_EXPORT_HEADER_TEMPLATE doesn't exist: ${Slicer_EXPORT_HEADER_TEMPLATE}")
  ENDIF(NOT EXISTS ${Slicer_EXPORT_HEADER_TEMPLATE})
  CONFIGURE_FILE(
    ${Slicer_EXPORT_HEADER_TEMPLATE}
    ${CMAKE_CURRENT_BINARY_DIR}/${MY_EXPORT_HEADER_PREFIX}Export.h
    )
  SET(dynamicHeaders
    "${dynamicHeaders};${CMAKE_CURRENT_BINARY_DIR}/${MY_EXPORT_HEADER_PREFIX}Export.h")

  #-----------------------------------------------------------------------------
  # Source group(s)
  
  SOURCE_GROUP("Generated" FILES
    ${dynamicHeaders}
    )

  # --------------------------------------------------------------------------
  # Build the library

  ADD_LIBRARY(${lib_name}
    ${MODULELOGIC_SRCS}
    )

  # Set loadable modules output path
  SET_TARGET_PROPERTIES(${lib_name}
    PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY
    "${CMAKE_BINARY_DIR}/${Slicer_INSTALL_MODULES_BIN_DIR}"
    LIBRARY_OUTPUT_DIRECTORY
    "${CMAKE_BINARY_DIR}/${Slicer_INSTALL_MODULES_LIB_DIR}"
    ARCHIVE_OUTPUT_DIRECTORY
    "${CMAKE_BINARY_DIR}/${Slicer_INSTALL_MODULES_LIB_DIR}"
    )

  # TODO: fix this
  # HACK Since we don't depend on qSlicerBaseQT{Base, Core, CLI, CoreModules, GUI},
  # let's remove them from the list
  SET(Slicer_ModuleLogic_Base_LIBRARIES ${Slicer_Base_LIBRARIES})
  LIST(REMOVE_ITEM Slicer_ModuleLogic_Base_LIBRARIES qSlicerBaseQTBase)
  LIST(REMOVE_ITEM Slicer_ModuleLogic_Base_LIBRARIES qSlicerBaseQTCore)
  LIST(REMOVE_ITEM Slicer_ModuleLogic_Base_LIBRARIES qSlicerBaseQTCLI)
  LIST(REMOVE_ITEM Slicer_ModuleLogic_Base_LIBRARIES qSlicerBaseQTCoreModules)
  LIST(REMOVE_ITEM Slicer_ModuleLogic_Base_LIBRARIES qSlicerBaseQTGUI)
  # Let's also remove dependency on SlicerBaseGUI
  LIST(REMOVE_ITEM Slicer_ModuleLogic_Base_LIBRARIES SlicerBaseGUI)

  TARGET_LINK_LIBRARIES(${lib_name}
    ${Slicer_Libs_LIBRARIES}
    ${Slicer_ModuleLogic_Base_LIBRARIES}
    ${MODULELOGIC_TARGET_LIBRARIES}
    )

  # Apply user-defined properties to the library target.
  IF(Slicer_LIBRARY_PROPERTIES)
    SET_TARGET_PROPERTIES(${lib_name} PROPERTIES
      ${Slicer_LIBRARY_PROPERTIES}
    )
  ENDIF(Slicer_LIBRARY_PROPERTIES)
  
  # Install rules
  INSTALL(TARGETS ${lib_name}
    RUNTIME DESTINATION ${Slicer_INSTALL_MODULES_BIN_DIR} COMPONENT RuntimeLibraries 
    LIBRARY DESTINATION ${Slicer_INSTALL_MODULES_LIB_DIR} COMPONENT RuntimeLibraries
    ARCHIVE DESTINATION ${Slicer_INSTALL_MODULES_LIB_DIR} COMPONENT Development
    )

  # Install headers
  FILE(GLOB headers "${CMAKE_CURRENT_SOURCE_DIR}/*.h")
  INSTALL(FILES
    ${headers}
    ${dynamicHeaders}
    DESTINATION ${Slicer_INSTALL_MODULES_INCLUDE_DIR}/${MODULELOGIC_NAME} COMPONENT Development
    )

  IF(VTK_WRAP_PYTHON AND BUILD_SHARED_LIBS)

    # TODO: A parameter named 'WRAPPED_TARGET_LIBRARIES'
    # should be added to the macro.
    # VTK wrapped libraries
    SET(VTK_WRAPPED_LIBRARIES
      vtkVolumeRendering
      )

    # TODO: Slicer's Use file should export this list automatically
    # (currently the wrapped and non-wrapped libs are mixed together)
    # See "HACK" above
    SET(Slicer_Wrapped_LIBRARIES
      vtkTeem vtkITK FreeSurfer MRML MRMLCLI MRMLLogic MRMLDisplayableManager
      RemoteIO SlicerBaseLogic
      )
    LIST(APPEND Slicer_Wrapped_LIBRARIES ${VTK_WRAPPED_LIBRARIES})

    INCLUDE(${VTK_CMAKE_DIR}/vtkWrapPython.cmake)
    VTK_WRAP_PYTHON3(${lib_name}Python PYTHON_SRCS "${MODULELOGIC_SRCS}")
    ADD_LIBRARY(${lib_name}PythonD ${PYTHON_SRCS})
    ADD_LIBRARY(${lib_name}Python MODULE ${lib_name}PythonInit.cxx)
    
    TARGET_LINK_LIBRARIES(${lib_name}PythonD ${lib_name} ${PYTHON_LIBRARIES})
    
    FOREACH(c ${Slicer_Wrapped_LIBRARIES})
      TARGET_LINK_LIBRARIES(${lib_name}PythonD ${c}PythonD ${c})
    ENDFOREACH(c)

    TARGET_LINK_LIBRARIES(${lib_name}Python ${lib_name}PythonD ${lib_name})

    ## Python modules on Windows must have the extension ".pyd"
    IF(WIN32 AND NOT CYGWIN)
      SET_TARGET_PROPERTIES(${lib_name}Python PROPERTIES SUFFIX ".pyd")
    ENDIF(WIN32 AND NOT CYGWIN)

    # Apply user-defined properties to the library target.
    IF(Slicer_LIBRARY_PROPERTIES)
      SET_TARGET_PROPERTIES(${lib_name}Python PROPERTIES
         ${Slicer_LIBRARY_PROPERTIES}
      )
      SET_TARGET_PROPERTIES(${lib_name}PythonD PROPERTIES
         ${Slicer_LIBRARY_PROPERTIES}
      )
    ENDIF(Slicer_LIBRARY_PROPERTIES)

    INSTALL(TARGETS ${lib_name}PythonD ${lib_name}Python
      RUNTIME DESTINATION ${Slicer_INSTALL_QTLOADABLEMODULES_BIN_DIR} COMPONENT RuntimeLibraries
      LIBRARY DESTINATION ${Slicer_INSTALL_QTLOADABLEMODULES_LIB_DIR} COMPONENT RuntimeLibraries
      ARCHIVE DESTINATION ${Slicer_INSTALL_QTLOADABLEMODULES_LIB_DIR} COMPONENT Development
      )

    # Generate "Python/<lib_name>.py" file
    FILE(WRITE ${CMAKE_CURRENT_BINARY_DIR}/Python/slicer/modulelogic/${lib_name}.py "
\"\"\" This module loads all the classes from the ${lib_name} library into its
namespace.\"\"\"

import os

if os.name == 'posix':
  from lib${lib_name}Python import *
else:
  from ${lib_name}Python import *

# Removing things the user shouldn't have to see.
del os
")

    FILE(GLOB PYFILES
      RELATIVE "${CMAKE_CURRENT_BINARY_DIR}/Python"
      "${CMAKE_CURRENT_BINARY_DIR}/Python/slicer/modulelogic/*.py")
    if ( PYFILES )
      ctkMacroCompilePythonScript(
        TARGET_NAME ${lib_name}
        SCRIPTS "${PYFILES}"
        RESOURCES ""
        SOURCE_DIR ${CMAKE_CURRENT_BINARY_DIR}/Python
        DESTINATION_DIR ${Slicer_BINARY_DIR}/bin/Python
        INSTALL_DIR ${Slicer_INSTALL_BIN_DIR}
        )
    ENDIF()

  ENDIF(VTK_WRAP_PYTHON AND BUILD_SHARED_LIBS)
    
ENDMACRO(SlicerMacroBuildModuleLogic)
